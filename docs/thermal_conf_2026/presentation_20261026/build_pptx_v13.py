#!/usr/bin/env python3
"""slides_draft_v13.md の内容を、大学テンプレート（16:9）上の編集可能なPPTXとして再構成する。

標準ライブラリとPillowだけを使い、テンプレートのXMLを直接組み立てる。
テキスト・図形・矢印・数式はPowerPointで編集可能なオブジェクト、図は既存PNG。
ノートは slides_draft_v13.md の各スライドの「目安」を含むコメントから取る。

    python3 docs/thermal_conf_2026/presentation_20261026/build_pptx_v13.py
"""
import re
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape

from PIL import Image

HERE = Path(__file__).resolve().parent
TEMPLATE = Path("/home/foo/slide/templates/TYPE-1_A_type_16-9_JA.pptx")
SOURCE_MD = HERE / "slides_draft_v13.md"
OUT = HERE / "slides_v13.pptx"

EMU = 914400
FONT = "Meiryo"
FOOTER = "大屋 蒼真（九州大学）"
MAROON = "6D0029"      # テンプレートの帯の色
ACCENT = "A13D22"      # 強調（v12と同じ）
TEXT = "25272B"
GRAY = "59616B"
TINT = "F6EDF2"        # 淡い強調背景
RESULT = "FFF1EB"      # 結果の背景
LINE_GRAY = "68707A"

NS = ('xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"')


def emu(v):
    return int(round(v * EMU))


# ---------------------------------------------------------------- テキスト
TOKEN = re.compile(r"(\*\*.+?\*\*|\*.+?\*|\{_.+?\}|\{\^.+?\})")


def runs_from(text, sz, color=TEXT, bold=False, emph=ACCENT):
    """簡易記法：**強調**、*斜体*、{_下付き}、{^上付き}。"""
    out = []
    for part in TOKEN.split(text):
        if not part:
            continue
        opt = dict(sz=sz, color=color, b=bold, i=False, base=0)
        if part.startswith("**"):
            part = part[2:-2]
            opt.update(b=True, color=emph)
        elif part.startswith("{_"):
            part = part[2:-1]
            opt.update(base=-25000, i=True)
        elif part.startswith("{^"):
            part = part[2:-1]
            opt.update(base=30000)
        elif part.startswith("*"):
            part = part[1:-1]
            opt.update(i=True)
        out.append((part, opt))
    return out


def rpr(opt, tag="a:rPr"):
    attrs = f'lang="ja-JP" altLang="en-US" sz="{int(opt["sz"] * 100)}"'
    if opt.get("b"):
        attrs += ' b="1"'
    if opt.get("i"):
        attrs += ' i="1"'
    if opt.get("base"):
        attrs += f' baseline="{opt["base"]}"'
    return (f'<{tag} {attrs} dirty="0"><a:solidFill><a:srgbClr val="{opt["color"]}"/></a:solidFill>'
            f'<a:latin typeface="{FONT}"/><a:ea typeface="{FONT}"/><a:cs typeface="{FONT}"/></{tag}>')


def para(text, sz=18, color=TEXT, bold=False, align="l", bullet=False, before=0, line=None, emph=ACCENT):
    """1段落。text 内の '\n' は段落内改行。"""
    ppr = f'<a:pPr algn="{align}"'
    if bullet:
        ppr += ' marL="285750" indent="-285750"'
    else:
        ppr += ' marL="0" indent="0"'
    ppr += '>'
    if line:
        ppr += f'<a:lnSpc><a:spcPct val="{int(line * 1000)}"/></a:lnSpc>'
    ppr += f'<a:spcBef><a:spcPts val="{int(before * 100)}"/></a:spcBef>'
    if bullet:
        ppr += f'<a:buClr><a:srgbClr val="{MAROON}"/></a:buClr><a:buFont typeface="Arial"/><a:buChar char="•"/>'
    else:
        ppr += '<a:buNone/>'
    ppr += '</a:pPr>'
    body = ""
    base_opt = dict(sz=sz, color=color, b=bold, i=False, base=0)
    for k, line_text in enumerate(text.split("\n")):
        if k:
            body += f'<a:br>{rpr(base_opt)}</a:br>'
        for t, opt in runs_from(line_text, sz, color, bold, emph):
            body += f'<a:r>{rpr(opt)}<a:t>{escape(t)}</a:t></a:r>'
    return f'<a:p>{ppr}{body}{rpr(base_opt, tag="a:endParaRPr")}</a:p>'


class Slide:
    def __init__(self, layout):
        self.layout = layout
        self.shapes = []
        self.next_id = 10
        self.images = []   # (rId, media name)

    def nid(self):
        self.next_id += 1
        return self.next_id

    def add(self, xml):
        self.shapes.append(xml)

    # 図形・テキスト
    def box(self, x, y, w, h, paras, fill=None, line=None, geom="rect", anchor="t",
            inset=(0.08, 0.05, 0.08, 0.05), name="Text", textbox=True, line_w=1.5):
        i = self.nid()
        sppr = (f'<a:xfrm><a:off x="{emu(x)}" y="{emu(y)}"/><a:ext cx="{emu(w)}" cy="{emu(h)}"/></a:xfrm>'
                f'<a:prstGeom prst="{geom}"><a:avLst/></a:prstGeom>')
        sppr += f'<a:solidFill><a:srgbClr val="{fill}"/></a:solidFill>' if fill else '<a:noFill/>'
        sppr += (f'<a:ln w="{int(line_w * 12700)}"><a:solidFill><a:srgbClr val="{line}"/></a:solidFill></a:ln>'
                 if line else '<a:ln><a:noFill/></a:ln>')
        l, t, r, b = (emu(v) for v in inset)
        cnv = '<p:cNvSpPr txBox="1"/>' if textbox else '<p:cNvSpPr/>'
        self.add(f'<p:sp><p:nvSpPr><p:cNvPr id="{i}" name="{name} {i}"/>{cnv}<p:nvPr/></p:nvSpPr>'
                 f'<p:spPr>{sppr}</p:spPr><p:txBody><a:bodyPr wrap="square" lIns="{l}" tIns="{t}" rIns="{r}" '
                 f'bIns="{b}" rtlCol="0" anchor="{anchor}"><a:noAutofit/></a:bodyPr><a:lstStyle/>'
                 f'{"".join(paras)}</p:txBody></p:sp>')

    def title(self, text, sz=28):
        i = self.nid()
        self.add(f'<p:sp><p:nvSpPr><p:cNvPr id="{i}" name="Title {i}"/><p:cNvSpPr><a:spLocks noGrp="1"/>'
                 f'</p:cNvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr><p:spPr><a:xfrm>'
                 f'<a:off x="{emu(0.6)}" y="{emu(0.98)}"/><a:ext cx="{emu(12.13)}" cy="{emu(0.66)}"/></a:xfrm>'
                 f'</p:spPr><p:txBody><a:bodyPr anchor="ctr"><a:normAutofit/></a:bodyPr><a:lstStyle/>'
                 f'{para(text, sz=sz, color=MAROON, bold=True)}</p:txBody></p:sp>')

    def slide_number(self):
        i = self.nid()
        self.add(f'<p:sp><p:nvSpPr><p:cNvPr id="{i}" name="Slide Number {i}"/><p:cNvSpPr><a:spLocks noGrp="1"/>'
                 f'</p:cNvSpPr><p:nvPr><p:ph type="sldNum" sz="quarter" idx="11"/></p:nvPr></p:nvSpPr><p:spPr/>'
                 f'<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:fld id="{{B6F15528-21DE-4FAA-801E-634DDDAF4B2B}}" '
                 f'type="slidenum"><a:rPr lang="en-US" altLang="ja-JP"/><a:t>‹#›</a:t></a:fld></a:p></p:txBody></p:sp>')

    def footer(self, text=None):
        """テンプレートの帯のフッタ欄（idx 10）。書式はレイアウトに従う。"""
        text = FOOTER if text is None else text
        i = self.nid()
        self.add(f'<p:sp><p:nvSpPr><p:cNvPr id="{i}" name="Footer {i}"/><p:cNvSpPr><a:spLocks noGrp="1"/>'
                 f'</p:cNvSpPr><p:nvPr><p:ph type="ftr" sz="quarter" idx="10"/></p:nvPr></p:nvSpPr><p:spPr/>'
                 f'<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr lang="ja-JP" altLang="en-US" dirty="0">'
                 f'<a:latin typeface="{FONT}"/><a:ea typeface="{FONT}"/></a:rPr><a:t>{escape(text)}</a:t></a:r></a:p>'
                 f'</p:txBody></p:sp>')

    def arrow(self, x1, y1, x2, y2, color=LINE_GRAY, w=2.25, head=True, name="Arrow"):
        i = self.nid()
        fh = ' flipH="1"' if x2 < x1 else ''
        fv = ' flipV="1"' if y2 < y1 else ''
        tail = '<a:tailEnd type="triangle" w="med" len="med"/>' if head else ''
        self.add(f'<p:cxnSp><p:nvCxnSpPr><p:cNvPr id="{i}" name="{name} {i}"/><p:cNvCxnSpPr/><p:nvPr/>'
                 f'</p:nvCxnSpPr><p:spPr><a:xfrm{fh}{fv}><a:off x="{emu(min(x1, x2))}" y="{emu(min(y1, y2))}"/>'
                 f'<a:ext cx="{emu(abs(x2 - x1))}" cy="{emu(abs(y2 - y1))}"/></a:xfrm>'
                 f'<a:prstGeom prst="straightConnector1"><a:avLst/></a:prstGeom><a:ln w="{int(w * 12700)}">'
                 f'<a:solidFill><a:srgbClr val="{color}"/></a:solidFill>{tail}</a:ln></p:spPr></p:cxnSp>')

    def picture(self, path, x, y, w=None, h=None, name="Figure"):
        path = Path(path)
        with Image.open(path) as im:
            pw, ph = im.size
        if w is None:
            w = h * pw / ph
        if h is None:
            h = w * ph / pw
        rid = f"rId{len(self.images) + 3}"
        self.images.append((rid, path))
        i = self.nid()
        self.add(f'<p:pic><p:nvPicPr><p:cNvPr id="{i}" name="{name} {i}" descr="{escape(path.name)}"/>'
                 f'<p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>'
                 f'<p:blipFill><a:blip r:embed="{rid}"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>'
                 f'<p:spPr><a:xfrm><a:off x="{emu(x)}" y="{emu(y)}"/><a:ext cx="{emu(w)}" cy="{emu(h)}"/></a:xfrm>'
                 f'<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>')
        return w, h

    def raw(self, xml):
        self.add(xml.replace("__ID__", str(self.nid())))

    def xml(self):
        return (f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<p:sld {NS}><p:cSld><p:spTree>'
                f'<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm>'
                f'<a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/>'
                f'</a:xfrm></p:grpSpPr>{"".join(self.shapes)}</p:spTree></p:cSld><p:clrMapOvr>'
                f'<a:masterClrMapping/></p:clrMapOvr></p:sld>')


# ---------------------------------------------------------------- 数式（OMML）
def m_run(t, sty=None):
    s = f'<m:rPr><m:sty m:val="{sty}"/></m:rPr>' if sty else ''
    italic = sty not in ("p", "b")
    bold = ' b="1"' if sty in ("b", "bi") else ''
    a = (f'<a:rPr lang="en-US" altLang="ja-JP" sz="2400" i="{1 if italic else 0}"{bold}>'
         f'<a:latin typeface="Cambria Math"/></a:rPr>')
    return f'<m:r>{s}{a}<m:t>{escape(t)}</m:t></m:r>'


def m_sub(base, sub):
    return f'<m:sSub><m:e>{base}</m:e><m:sub>{sub}</m:sub></m:sSub>'


def rom_equation(x, y, w, h):
    X = m_run("x", "b")
    MU = m_run("μ", "bi")
    paren = lambda inner: f'<m:d><m:dPr><m:ctrlPr><a:rPr lang="en-US" i="1"><a:latin typeface="Cambria Math"/></a:rPr></m:ctrlPr></m:dPr><m:e>{inner}</m:e></m:d>'
    tbar = f'<m:bar><m:barPr><m:pos m:val="top"/></m:barPr><m:e>{m_run("T")}</m:e></m:bar>'
    summand = m_sub(m_run("a"), m_run("j")) + paren(MU) + m_sub(m_run("ϕ"), m_run("j")) + paren(X)
    nary = (f'<m:nary><m:naryPr><m:chr m:val="∑"/><m:limLoc m:val="undOvr"/></m:naryPr>'
            f'<m:sub>{m_run("j")}{m_run("=", "p")}{m_run("1", "p")}</m:sub><m:sup>{m_run("r")}</m:sup>'
            f'<m:e>{summand}</m:e></m:nary>')
    omath = (m_run("T") + paren(X + m_run(";", "p") + MU) + m_run("≈", "p") + tbar + paren(X)
             + m_run("+", "p") + nary)
    math = ('<a14:m xmlns:a14="http://schemas.microsoft.com/office/drawing/2010/main">'
            '<m:oMathPara xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math">'
            f'<m:oMathParaPr><m:jc m:val="centerGroup"/></m:oMathParaPr><m:oMath>{omath}</m:oMath></m:oMathPara></a14:m>')
    xfrm = f'<a:xfrm><a:off x="{emu(x)}" y="{emu(y)}"/><a:ext cx="{emu(w)}" cy="{emu(h)}"/></a:xfrm>'
    sp = lambda body: (f'<p:sp><p:nvSpPr><p:cNvPr id="__ID__" name="Equation"/><p:cNvSpPr txBox="1"/><p:nvPr/>'
                       f'</p:nvSpPr><p:spPr>{xfrm}<a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/>'
                       f'</p:spPr><p:txBody><a:bodyPr wrap="square" anchor="ctr"><a:noAutofit/></a:bodyPr>'
                       f'<a:lstStyle/>{body}</p:txBody></p:sp>')
    choice = sp(f'<a:p><a:pPr algn="ctr"/>{math}<a:endParaRPr lang="en-US" sz="2400"/></a:p>')
    fallback = sp(para("T(x; μ) ≈ T̄(x) + Σ_{j=1}^{r} a_j(μ) φ_j(x)", sz=22, align="ctr"))
    return ('<mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006">'
            '<mc:Choice xmlns:a14="http://schemas.microsoft.com/office/drawing/2010/main" Requires="a14">'
            f'{choice}</mc:Choice><mc:Fallback>{fallback}</mc:Fallback></mc:AlternateContent>')


# ---------------------------------------------------------------- ノート
def read_notes():
    text = SOURCE_MD.read_text(encoding="utf-8")
    parts = text.split("\n---\n")
    slides = parts[1:] if text.startswith("---") else parts
    notes = []
    for s in slides:
        found = [c.strip() for c in re.findall(r"<!--(.*?)-->", s, flags=re.S) if "目安" in c]
        notes.append(found[-1] if found else "")
    return notes


def notes_xml(text):
    paras = "".join(
        f'<a:p><a:r><a:rPr lang="ja-JP" altLang="en-US" dirty="0"><a:latin typeface="{FONT}"/>'
        f'<a:ea typeface="{FONT}"/></a:rPr><a:t>{escape(line)}</a:t></a:r></a:p>'
        for line in text.splitlines()) or '<a:p><a:endParaRPr lang="ja-JP"/></a:p>'
    return (f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<p:notes {NS}><p:cSld><p:spTree>'
            f'<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>'
            f'<p:sp><p:nvSpPr><p:cNvPr id="2" name="Slide Image Placeholder 1"/><p:cNvSpPr><a:spLocks noGrp="1" '
            f'noRot="1" noChangeAspect="1"/></p:cNvSpPr><p:nvPr><p:ph type="sldImg"/></p:nvPr></p:nvSpPr><p:spPr/></p:sp>'
            f'<p:sp><p:nvSpPr><p:cNvPr id="3" name="Notes Placeholder 2"/><p:cNvSpPr><a:spLocks noGrp="1"/>'
            f'</p:cNvSpPr><p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr><p:spPr/><p:txBody><a:bodyPr/>'
            f'<a:lstStyle/>{paras}</p:txBody></p:sp></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/>'
            f'</p:clrMapOvr></p:notes>')


# ---------------------------------------------------------------- スライド（16:9、13.33 × 7.5 in）
F = HERE
FIG = HERE.parent / "figures"
W = 13.333
L, R = 0.6, 12.73          # 本文の左右端
CW = R - L


def s_title():
    s = Slide(1)
    i = s.nid()
    s.add(f'<p:sp><p:nvSpPr><p:cNvPr id="{i}" name="Title {i}"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>'
          f'<p:nvPr><p:ph type="ctrTitle"/></p:nvPr></p:nvSpPr><p:spPr><a:xfrm><a:off x="{emu(0.8)}" y="{emu(1.3)}"/>'
          f'<a:ext cx="{emu(11.73)}" cy="{emu(1.5)}"/></a:xfrm></p:spPr><p:txBody><a:bodyPr anchor="ctr"><a:normAutofit/>'
          f'</a:bodyPr><a:lstStyle/>'
          f'{para("TSV密度マップを用いた縮約モデルによる" + chr(10) + "3D-ICの熱設計最適化の研究", sz=32, color="FFFFFF", bold=True, align="ctr", line=115)}'
          f'</p:txBody></p:sp>')
    i = s.nid()
    s.add(f'<p:sp><p:nvSpPr><p:cNvPr id="{i}" name="Subtitle {i}"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>'
          f'<p:nvPr><p:ph type="subTitle" idx="1"/></p:nvPr></p:nvSpPr><p:spPr><a:xfrm><a:off x="{emu(0.8)}" y="{emu(3.0)}"/>'
          f'<a:ext cx="{emu(11.73)}" cy="{emu(0.6)}"/></a:xfrm></p:spPr><p:txBody><a:bodyPr anchor="ctr"><a:normAutofit/>'
          f'</a:bodyPr><a:lstStyle/>{para("熱工学コンファレンス2026　B11", sz=20, color="FFFFFF", align="ctr")}'
          f'</p:txBody></p:sp>')
    s.box(0.8, 4.5, 11.73, 1.0, [para("大屋 蒼真・小野 謙二", sz=22, align="ctr"),
                                 para("九州大学", sz=18, align="ctr", before=4)], name="Authors")
    return s


def s_background():
    s = Slide(4)
    s.title("3D-ICの熱問題とTSV配置")
    s.slide_number()
    s.footer()
    s.box(L, 2.0, 7.6, 0.65, [para("ICの立体集積による**熱問題**が課題", sz=24)])
    s.arrow(1.15, 2.75, 1.15, 3.35, color=MAROON)
    s.box(L, 3.4, 7.6, 1.1, [para("チップ内の熱輸送に影響する**TSV**の\n**配置の最適化**が必要", sz=24, line=115)])
    s.box(L, 4.55, 7.6, 0.45, [para("TSV（through-silicon via）：層を貫通する配線", sz=15, color=GRAY)])
    s.box(L, 5.3, 7.6, 0.8, [para("TSV配置を高速に評価し、低温な配置を探す", sz=22, bold=True, color=ACCENT)],
          fill=TINT, anchor="ctr", inset=(0.18, 0.05, 0.1, 0.05), name="Conclusion")
    s.box(L, 6.55, 7.6, 0.6, [para("右上：3D-ICイメージ図", sz=11, color=GRAY),
                              para("右下：NIST, “3D stacked integrated circuit”, nist.gov/image/3dicjpg", sz=11, color=GRAY)],
          name="Source")
    s.picture(F / "intro_3dic_thermal_v4.png", 8.55, 1.05, w=4.4, name="3D-IC image")
    s.picture(FIG / "3d_ic.jpg", 8.75, 3.75, w=4.0, name="NIST TSV figure")
    return s


def s_flow():
    s = Slide(4)
    s.title("本研究の流れ")
    s.slide_number()
    s.footer()
    steps = [("入力を減らす", "膨大な配置パラメータを圧縮"),
             ("近似モデル", "事前の計算によって温度場を高速に予測"),
             ("探索", "多数の配置を評価し、低温な候補を選ぶ"),
             ("確認", "選んだ候補をFVM（有限体積法）で再計算")]
    y0, pitch, d = 2.05, 1.22, 0.78
    xc = 1.05                      # 番号の円の左端
    cx = xc + d / 2
    # 番号どうしを結ぶ縦線（円の後ろ）
    s.arrow(cx, y0 + pitch / 2, cx, y0 + pitch * 3.5, color=MAROON, w=3, head=False, name="Connector")
    for k, (label, desc) in enumerate(steps):
        yc = y0 + pitch * (k + 0.5)
        if k < 3:
            s.arrow(xc, y0 + pitch * (k + 1), 12.4, y0 + pitch * (k + 1), color="E3E5E8", w=0.75,
                    head=False, name="Separator")
        s.box(xc, yc - d / 2, d, d, [para(str(k + 1), sz=24, bold=True, color="FFFFFF", align="ctr")],
              fill=MAROON, geom="ellipse", anchor="ctr", inset=(0, 0, 0, 0), textbox=False, name="StepNo")
        s.box(2.25, yc - 0.35, 3.0, 0.7, [para(label, sz=24, bold=True, color=MAROON)], anchor="ctr",
              name="StepLabel")
        s.box(5.25, yc - 0.35, 7.1, 0.7, [para(desc, sz=22)], anchor="ctr", name="StepText")
    return s


def s_model():
    s = Slide(4)
    s.title("解析モデル")
    s.slide_number()
    s.footer()
    s.picture(F / "model_xy_uniform_N48_v9.png", 1.35, 1.7, h=2.8, name="Model XY")
    s.picture(F / "model_yz_uniform_N48_v9.png", 0.6, 4.55, w=4.6, name="Model YZ")
    s.box(0.6, 7.05, 4.6, 0.35, [para("上：XY断面　下：YZ断面（一様配置 *N* = 48）", sz=12, color=GRAY, align="ctr")])
    s.box(5.9, 1.85, 6.8, 3.6, [
        para("1.2 mm角・厚さ0.6 mmの**3層積層モデル**", sz=20, bullet=True),
        para("各Si層に**発熱ブロック4個**\n総発熱量**0.384 W**", sz=20, bullet=True, before=10),
        para("上面：周囲**300 K**への対流\n側面・下面：断熱", sz=20, bullet=True, before=10),
        para("中央1 mm角がTSV実装領域\n（TSV配置は3層共通）", sz=20, bullet=True, before=10),
        para("FVM：240×240×30セル", sz=20, bullet=True, before=10)])
    s.box(5.9, 5.75, 6.8, 0.95, [para("黄：Cu TSV　灰：Si　赤：発熱ブロック\n紫：バンプ　緑：樹脂　青：Alスプレッダ　橙：PCB",
                                      sz=15, line=120)], fill="F5F5F6", anchor="ctr", inset=(0.18, 0.05, 0.1, 0.05),
          name="Legend")
    return s


def s_density():
    s = Slide(4)
    s.title("TSV密度マップ")
    s.slide_number()
    s.footer()
    s.box(L, 1.75, CW, 0.95, [para("TSV座標をそのまま入力とすると、本数 *N* に応じて入力数が増加", sz=20),
                              para("→ TSV実装領域を4×4に分割し、**各セルのTSV本数**を入力とする", sz=20, before=4)])
    dw, _ = s.picture(F / "density_map_random_N48_v6.png", 1.7, 2.85, h=3.4, name="Density map")
    s.arrow(1.7 + dw + 0.25, 4.45, 1.7 + dw + 1.05, 4.45)
    s.box(1.7 + dw + 0.15, 4.55, 1.0, 0.4, [para("展開", sz=15, color=GRAY, align="ctr")])
    s.picture(F / "material_xy_random_N48_v6.png", 1.7 + dw + 1.3, 2.85, h=3.4, name="Expanded layout")
    s.box(L, 6.45, CW, 0.65, [para("入力：TSV座標 2*N* 個 → 密度マップ **16 個**に圧縮（*N* によらず一定）", sz=20, align="ctr")],
          fill=TINT, geom="roundRect", anchor="ctr", textbox=False, name="Compression")
    return s


def s_rom():
    s = Slide(4)
    s.title("縮約モデル（ROM）")
    s.slide_number()
    s.footer()
    s.box(L, 1.75, CW, 1.2, [para("FVM（有限体積法）で**300配置**の温度場を計算し、**主要な空間パターン24個**をPODで抽出", sz=20, line=115),
                             para("POD：多数の温度場から、変化への寄与が大きい順に空間パターンを取り出す手法", sz=15, color=GRAY, before=6)])
    s.raw(rom_equation(1.2, 3.2, 7.6, 1.5))
    s.box(9.3, 3.25, 3.4, 1.4, [para("*ϕ*{_j}：空間パターン", sz=18), para("*a*{_j}：係数", sz=18, before=4),
                                para("*r*：パターン数", sz=18, before=4)],
          fill="F5F5F6", anchor="ctr", inset=(0.2, 0.05, 0.1, 0.05), name="Symbols")
    s.box(L, 5.2, CW, 0.8, [para("重ね合わせの係数 *a*{_j} は、密度マップ **μ**（16個）から**RBF補間**によって予測", sz=20)],
          fill=TINT, anchor="ctr", inset=(0.2, 0.05, 0.1, 0.05), name="Coefficient")
    return s


def s_accuracy():
    s = Slide(4)
    s.title("ROMの精度検証結果")
    s.slide_number()
    s.footer()
    s.picture(F / "rom_accuracy_independent_v7.png", 0.45, 1.7, h=5.45, name="Accuracy plot")
    x, w = 7.75, 5.0
    s.box(x, 2.0, w, 2.3, [
        para("**横軸**：FVMの最高温度\n**縦軸**：ROMの最高温度", sz=19, emph=MAROON, line=115),
        para("ROMの構築に使っていない\n**42配置**で評価", sz=19, bullet=True, before=12),
        para("破線（y = x）からの距離＝\nFVMとROMの最高温度の誤差", sz=19, bullet=True, before=6)])
    s.box(x, 4.55, w, 1.95, [
        para("結果", sz=19, bold=True, color=MAROON),
        para("最高温度の平均誤差：**0.0950 K**", sz=19, before=4),
        para("温度場の2乗平均誤差：**0.493 %**", sz=19, before=4),
        para("（300 Kからの温度上昇に対する比）", sz=13, color=GRAY, before=2)],
          fill=RESULT, anchor="ctr", inset=(0.2, 0.05, 0.1, 0.05), name="Result")
    return s


def s_search():
    s = Slide(4)
    s.title("最適配置の探索")
    s.slide_number()
    s.footer()
    s.box(L, 1.75, CW, 0.55, [para("各TSV本数（*N* = 36〜60）を固定し、ROMが予測する最高温度を最小化", sz=20)])
    w, h, y, gap = 3.0, 1.4, 2.8, 0.9
    x0 = (W - (3 * w + 2 * gap)) / 2
    xs = [x0 + k * (w + gap) for k in range(3)]
    texts = [("初期配置", None), ("近傍の配置を\n最大240個\nROMで評価", TINT), ("最良の配置を\n新たな出発点に更新", None)]
    for x, (t, fill) in zip(xs, texts):
        s.box(x, y, w, h, [para(t, sz=18, align="ctr", line=110)], fill=fill or "FFFFFF",
              line=MAROON, geom="roundRect", anchor="ctr", textbox=False, name="Step")
    for k in range(2):
        s.arrow(xs[k] + w + 0.1, y + h / 2, xs[k + 1] - 0.1, y + h / 2)
    # 更新 → 評価へ戻るU字の矢印
    bx3, bx2, yb, yl = xs[2] + w / 2, xs[1] + w / 2, y + h, y + h + 0.6
    s.arrow(bx3, yb, bx3, yl, color=MAROON, head=False, name="Loop")
    s.arrow(bx3, yl, bx2, yl, color=MAROON, head=False, name="Loop")
    s.arrow(bx2, yl, bx2, yb + 0.02, color=MAROON, name="Loop")
    s.box(bx2, yl + 0.05, bx3 - bx2, 0.45, [para("改善がなくなるまで繰り返す", sz=17, color=MAROON, align="ctr")])
    s.box(L, 5.75, CW, 0.75, [para("このサイクルを**400個の初期配置**で行い、最も低温な配置を採用", sz=20)],
          fill=TINT, anchor="ctr", inset=(0.2, 0.05, 0.1, 0.05), name="Multistart")
    return s


def s_results():
    s = Slide(4)
    s.title("TSV本数ごとの探索結果")
    s.slide_number()
    s.footer()
    s.picture(F / "tmax_vs_count_v10.png", L, 1.7, w=CW, name="Results plot")
    s.box(L, 5.35, 4.1, 0.8, [para("**横軸**：TSV本数 *N*", sz=17, emph=MAROON),
                              para("**縦軸**：ROMが予測した最高温度", sz=17, emph=MAROON, before=2)])
    s.box(L + 4.2, 5.35, 3.2, 0.8, [para("**灰**：一様配置", sz=17, emph=MAROON),
                                    para("**青**：探索で得た低温候補", sz=17, emph=MAROON, before=2)])
    s.box(L, 6.2, 7.2, 0.95, [
        para("*N* = 36〜60の**25水準**（ROM予測値）", sz=17, bullet=True),
        para("同じ本数で、配置による最高温度の違いを見る", sz=17, bullet=True, before=3)])
    s.box(8.2, 5.3, 4.53, 1.45, [
        para("結果", sz=18, bold=True, color=MAROON),
        para("全25水準で探索候補が\n一様配置より低温", sz=17, before=3),
        para("差：**1.09〜1.57 K**", sz=17, before=3)],
          fill=RESULT, anchor="ctr", inset=(0.2, 0.05, 0.1, 0.05), name="Result")
    s.box(8.2, 6.75, 4.53, 0.4, [para("本数ごとの局所探索の結果（大域最適解ではない）", sz=13, color=GRAY)])
    return s


def s_fvm():
    s = Slide(4)
    s.title("探索候補のFVM再検証")
    s.slide_number()
    s.footer()
    cw = 2.95
    for k, (head, dm, tm) in enumerate([("探索で得た低温候補", "density_map_best_N48_v11.png", "temperature_best_N48_v11.png"),
                                       ("一様配置", "density_map_uniform_N48_v11.png", "temperature_uniform_N48_v11.png")]):
        x = 0.5 + k * (cw + 0.15)
        s.box(x, 1.65, cw, 0.4, [para(head, sz=16, bold=True, align="ctr")])
        _, ih = s.picture(F / dm, x, 2.07, w=cw, name="Density map")
        s.picture(F / tm, x, 2.07 + ih + 0.08, w=cw, name="FVM temperature")
    rx, rw = 6.85, 5.88
    s.box(rx, 1.8, rw, 0.85, [para("**上**：密度マップ（*N* = 48）", sz=17, emph=MAROON),
                              para("**下**：FVM温度場（最下層Si層の発熱層）", sz=17, emph=MAROON, before=2)])
    s.box(rx, 2.85, rw, 1.95, [
        para("FVM最高温度", sz=18, bold=True, color=MAROON),
        para("探索候補：**315.618 K**", sz=18, before=3),
        para("一様配置：316.994 K", sz=18, before=3),
        para("差：**1.376 K**（温度上昇の**8.1 %**）", sz=18, before=3)],
          fill=RESULT, anchor="ctr", inset=(0.2, 0.05, 0.1, 0.05), name="Result")
    s.box(rx, 5.0, rw, 1.0, [
        para("ROMの予測との差", sz=18, bold=True, color=MAROON),
        para("探索候補：0.035 K　一様配置：0.002 K", sz=18, before=3)],
          fill=TINT, anchor="ctr", inset=(0.2, 0.05, 0.1, 0.05), name="ROM gap")
    s.box(rx, 6.2, rw, 0.75, [para("温度上昇：一様配置の最高温度 − 300 K", sz=13, color=GRAY),
                              para("固定した発熱分布・解析条件での低温候補", sz=13, color=GRAY, before=2)])
    return s


def s_summary():
    s = Slide(4)
    s.title("まとめ")
    s.slide_number()
    s.footer()
    s.box(L, 1.75, CW, 0.8, [para("密度マップを入力とするROMで、FVMで再計算すべき低温配置の候補を選別できた", sz=22, bold=True, color=ACCENT)],
          fill=TINT, anchor="ctr", inset=(0.2, 0.05, 0.1, 0.05), name="Conclusion")
    s.box(L, 2.8, CW, 2.0, [
        para("TSV配置を密度マップ（16個の値）に圧縮", sz=19, bullet=True),
        para("FVM 300配置の温度場からROMを構築", sz=19, bullet=True, before=6),
        para("*N* = 36〜60の25水準を、各400初期配置から探索", sz=19, bullet=True, before=6),
        para("選んだ候補をFVMで再計算", sz=19, bullet=True, before=6)])
    boxes = [("ROMの最高温度の平均誤差", "0.095 K"),
             ("FVMで確認した最高温度の低減\n（温度上昇比）", "7.1〜8.1 %"),
             ("ROMとFVMの差\n（*N* = 48）", "0.035 K")]
    gap = 0.3
    w = (CW - 2 * gap) / 3
    for k, (label, value) in enumerate(boxes):
        x = L + k * (w + gap)
        s.box(x, 5.0, w, 1.75, [para(label, sz=16, align="ctr", line=110),
                                para(value, sz=30, bold=True, color=ACCENT, align="ctr", before=6)],
              fill="FFFFFF", line=MAROON, geom="roundRect", anchor="ctr", textbox=False, name="Result")
    return s


BUILDERS = [s_title, s_background, s_flow, s_model, s_density, s_rom, s_accuracy, s_search, s_results, s_fvm,
            s_summary]


# ---------------------------------------------------------------- パッケージ
def main():
    notes = read_notes()
    if len(notes) != len(BUILDERS):
        sys.exit(f"ノート数 {len(notes)} とスライド数 {len(BUILDERS)} が一致しない")
    work = Path(tempfile.mkdtemp())
    with zipfile.ZipFile(TEMPLATE) as z:
        z.extractall(work)
    ppt = work / "ppt"
    # 既存スライドとノートを除去
    for d in ("slides", "notesSlides"):
        shutil.rmtree(ppt / d)
        (ppt / d / "_rels").mkdir(parents=True)
    ct = (work / "[Content_Types].xml").read_text(encoding="utf-8")
    ct = re.sub(r'<Override PartName="/ppt/(slides|notesSlides)/[^"]+"[^>]*/>', "", ct)
    if 'Extension="jpg"' not in ct:
        ct = ct.replace('<Default Extension="png"', '<Default Extension="jpg" ContentType="image/jpeg"/><Default Extension="png"')
    rels = (ppt / "_rels" / "presentation.xml.rels").read_text(encoding="utf-8")
    rels = re.sub(r'<Relationship Id="[^"]+" Type="[^"]+/slide" Target="slides/[^"]+"/>', "", rels)
    pres = (ppt / "presentation.xml").read_text(encoding="utf-8")

    # テーマのフォントをメイリオに
    theme = ppt / "theme" / "theme1.xml"
    th = theme.read_text(encoding="utf-8")
    th = re.sub(r'(<a:(major|minor)Font><a:latin typeface=")[^"]*("/><a:ea typeface=")[^"]*(")',
                lambda m: f'{m.group(1)}{FONT}{m.group(3)}{FONT}{m.group(4)}', th)
    theme.write_text(th, encoding="utf-8")

    sld_ids, new_rels, overrides = [], [], []
    media = ppt / "media"
    for n, (build, note) in enumerate(zip(BUILDERS, notes), start=1):
        s = build()
        (ppt / "slides" / f"slide{n}.xml").write_text(s.xml(), encoding="utf-8")
        srels = [f'<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout{s.layout}.xml"/>',
                 f'<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide" Target="../notesSlides/notesSlide{n}.xml"/>']
        for rid, path in s.images:
            name = f"v13_{path.stem}{path.suffix.lower()}"
            shutil.copy(path, media / name)
            srels.append(f'<Relationship Id="{rid}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/{name}"/>')
        (ppt / "slides" / "_rels" / f"slide{n}.xml.rels").write_text(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            + "".join(srels) + "</Relationships>", encoding="utf-8")
        (ppt / "notesSlides" / f"notesSlide{n}.xml").write_text(notes_xml(note), encoding="utf-8")
        (ppt / "notesSlides" / "_rels" / f"notesSlide{n}.xml.rels").write_text(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            f'<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesMaster" Target="../notesMasters/notesMaster1.xml"/>'
            f'<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="../slides/slide{n}.xml"/>'
            "</Relationships>", encoding="utf-8")
        rid = f"rId{200 + n}"
        sld_ids.append(f'<p:sldId id="{300 + n}" r:id="{rid}"/>')
        new_rels.append(f'<Relationship Id="{rid}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide{n}.xml"/>')
        overrides.append(f'<Override PartName="/ppt/slides/slide{n}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>'
                         f'<Override PartName="/ppt/notesSlides/notesSlide{n}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml"/>')

    pres = re.sub(r"<p:sldIdLst>.*?</p:sldIdLst>", "<p:sldIdLst>" + "".join(sld_ids) + "</p:sldIdLst>", pres, flags=re.S)
    (ppt / "presentation.xml").write_text(pres, encoding="utf-8")
    rels = rels.replace("</Relationships>", "".join(new_rels) + "</Relationships>")
    (ppt / "_rels" / "presentation.xml.rels").write_text(rels, encoding="utf-8")
    ct = ct.replace("</Types>", "".join(overrides) + "</Types>")
    (work / "[Content_Types].xml").write_text(ct, encoding="utf-8")

    if OUT.exists():
        OUT.unlink()
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        # [Content_Types].xml を先頭に置く
        z.write(work / "[Content_Types].xml", "[Content_Types].xml")
        for p in sorted(work.rglob("*")):
            if p.is_file() and p.name != "[Content_Types].xml":
                z.write(p, p.relative_to(work).as_posix())
    shutil.rmtree(work)
    print("written", OUT)


if __name__ == "__main__":
    main()
