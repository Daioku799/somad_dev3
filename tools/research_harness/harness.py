#!/usr/bin/env python3
"""範囲と承認記録を検査するだけのCLI。コマンド実行・承認発行はしない。"""
import argparse
import hashlib
import json
import re
from pathlib import Path


class Rejected(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise Rejected(message)


def nonempty(value):
    return isinstance(value, str) and bool(value.strip())


def keys(value, required, optional=()):
    require(isinstance(value, dict), 'objectが必要です')
    require(set(required) <= value.keys(), '必須項目が不足しています')
    require(value.keys() <= set(required) | set(optional), '未対応の項目があります')


def strings(value, allow_empty=True):
    return (isinstance(value, list) and (allow_empty or bool(value))
            and all(nonempty(x) for x in value) and len(value) == len(set(value)))


def json_hash(value):
    try:
        data = json.dumps(value, ensure_ascii=False, sort_keys=True,
                          separators=(',', ':'), allow_nan=False).encode('utf-8')
    except (ValueError, TypeError) as exc:
        raise Rejected('JSONとして正規化できません') from exc
    return hashlib.sha256(data).hexdigest()


def no_duplicates(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'JSONのキーが重複しています')
        result[key] = value
    return result


def read_json(path):
    require(Path(path).stat().st_size <= 8 * 1024 * 1024, 'JSONが8MiBを超えています')
    return json.loads(Path(path).read_text(encoding='utf-8'), object_pairs_hook=no_duplicates)


def write_path(root, name):
    require(nonempty(name), '書込対象が空です')
    path = Path(name)
    require(not path.is_absolute() and path.parts and '..' not in path.parts
            and not any(c in name for c in '*?[]') and path.as_posix() == name,
            '書込対象はroot内の正確な相対ファイル名にしてください')
    require(path.parts[0] != '.git', '.gitは書込対象にできません')
    cursor = root
    for part in path.parts:
        cursor = cursor / part
        require(not cursor.is_symlink(), '書込対象にsymlinkは指定できません')
    resolved = (root / path).resolve()
    require(resolved != root and resolved.is_relative_to(root), '書込対象がroot外です')
    require(not resolved.is_dir(), '書込対象にディレクトリは指定できません')
    return resolved


def bounded_bytes(path):
    # 大型runの全読込はしない。必要なら人が選んだ小さい資料へ切り出す。
    require(path.is_file() and path.stat().st_size <= 8 * 1024 * 1024,
            '参照は既存の8MiB以下のファイルに限定します')
    return path.read_bytes()


def markdown_headings(lines):
    """コードfence内の見出し風文字列で承認対象節を切らない。"""
    fence = None
    for i, line in enumerate(lines):
        marker = re.match(r'^ {0,3}(`{3,}|~{3,})(.*)$', line.rstrip('\r\n'))
        if fence is not None:
            if (marker and marker[1][0] == fence[0] and len(marker[1]) >= fence[1]
                    and not marker[2].strip()):
                fence = None
            continue
        if marker:
            fence = (marker[1][0], len(marker[1]))
            continue
        heading = re.match(r'^(#{1,6}) ', line)
        if heading:
            yield i, len(heading[1]), line.rstrip('\r\n')


def reference_hash(root, ref):
    keys(ref, ['path'], ['heading'])
    require(nonempty(ref['path']), '参照pathが空です')
    path = (root / ref['path']).resolve()
    data = bounded_bytes(path)
    if 'heading' in ref:
        heading = ref['heading']
        require(nonempty(heading) and re.fullmatch(r'#{1,6} .+', heading), 'headingが不正です')
        lines = data.decode('utf-8').splitlines(keepends=True)
        headings = list(markdown_headings(lines))
        hits = [i for i, _, text in headings if text == heading]
        require(len(hits) == 1, '対象headingが存在しないか重複しています')
        start = hits[0]
        level = len(heading.split(' ', 1)[0])
        end = len(lines)
        for i, next_level, _ in headings:
            if i > start and next_level <= level:
                end = i
                break
        data = ''.join(lines[start:end]).encode('utf-8')
    return {'path': str(path), 'sha256': hashlib.sha256(data).hexdigest()}


def presentation_valid(presentation, refs):
    keys(presentation, ['claims', 'figures'])
    claims, figures = presentation['claims'], presentation['figures']
    require(isinstance(claims, dict) and claims, '掲載する主張が必要です')
    require(isinstance(figures, dict), 'figuresはobjectです')
    for cid, claim in claims.items():
        keys(claim, ['text', 'evidence'])
        require(nonempty(cid) and nonempty(claim['text']), '主張が空です')
        require(strings(claim['evidence'], False) and set(claim['evidence']) <= refs,
                '主張の根拠はreferencesに登録してください')
    for fid, figure in figures.items():
        keys(figure, ['inputs', 'series', 'transform', 'axes', 'claims'])
        require(nonempty(fid) and strings(figure['inputs'], False)
                and set(figure['inputs']) <= refs, '図の入力がreferencesにありません')
        require(strings(figure['series'], False), '図の系列IDが必要です')
        require(nonempty(figure['transform']), '変換・集計・正規化を明示してください')
        require(isinstance(figure['axes'], dict) and figure['axes']
                and all(nonempty(k) and nonempty(v) for k, v in figure['axes'].items()),
                '図の軸・単位が必要です')
        require(strings(figure['claims'], False) and set(figure['claims']) <= claims.keys(),
                '図の対応主張がありません')


def scope_hash(order, root):
    root = Path(root).resolve()
    keys(order, ['schema_version', 'id', 'scope', 'state', 'approvals'],
         ['notes', 'presentation_acceptance'])
    require(type(order['schema_version']) is int and order['schema_version'] == 1,
            '未対応schema_versionです')
    require(nonempty(order['id']), '作業IDが空です')
    scope = order['scope']
    keys(scope, ['objective', 'task_refs', 'decisions', 'unresolved', 'references',
                 'operations', 'presentation'])
    require(nonempty(scope['objective']) and strings(scope['task_refs'], False), '目的・taskが必要です')
    require(isinstance(scope['decisions'], dict)
            and all(nonempty(k) and nonempty(v) for k, v in scope['decisions'].items()),
            '決定事項はIDと明示内容のobjectです。未決はunresolvedへ記録してください')
    require(strings(scope['unresolved']), '未決一覧の型が不正です')
    operations = scope['operations']
    require(isinstance(operations, dict) and operations
            and (operations.keys() <= {'implement', 'test'} or set(operations) == {'slides'}),
            '一作業票はimplement/test系またはslides系に限定します')
    for action, operation in operations.items():
        keys(operation, ['write_files', 'commands'])
        require(strings(operation['write_files']), '編集先一覧の型が不正です')
        for path in operation['write_files']:
            write_path(root, path)
        commands = operation['commands']
        require(isinstance(commands, list)
                and all(isinstance(c, list) and c and all(nonempty(a) for a in c) for c in commands),
                'commandsはargvの配列です')
        require(action != 'implement' or not commands, '実装許可にコマンド実行を含めないでください')
    refs = scope['references']
    require(isinstance(refs, list) and 0 < len(refs) <= 16, 'referencesは1〜16件必要です')
    hashes = [reference_hash(root, ref) for ref in refs]
    require((scope['presentation'] is not None) == ('slides' in operations),
            '掲載計画はslides系だけに必要です')
    if scope['presentation'] is not None:
        presentation_valid(scope['presentation'], {r['path'] for r in refs})
    return json_hash({'schema_version': 1, 'id': order['id'], 'root': str(root),
                      'scope': scope, 'current_references': hashes})


def receipt_valid(receipt, digest):
    require(isinstance(receipt, dict), '本人の承認記録がありません')
    require(nonempty(receipt.get('user_message')) and nonempty(receipt.get('user_quote')),
            '本人の明示承認への参照・引用が必要です（AIレビューは承認ではありません）')
    require(receipt.get('scope_hash') == digest, '承認scope hashが現在の範囲と一致しません')


def check_manifest(manifest, scope, root):
    keys(manifest, ['presentation', 'artifacts'])
    require(manifest['presentation'] == scope['presentation'], '掲載内容・図の系列・変換が承認範囲と違います')
    require(isinstance(manifest['artifacts'], list) and manifest['artifacts'], '成果物一覧が空です')
    seen = set()
    for artifact in manifest['artifacts']:
        keys(artifact, ['path', 'sha256'])
        name = artifact['path']
        require(nonempty(name) and name in scope['operations']['slides']['write_files'] and name not in seen,
                '成果物が範囲外か重複しています')
        seen.add(name)
        data = bounded_bytes(write_path(root, name))
        require(hashlib.sha256(data).hexdigest() == artifact['sha256'], '成果物のhashが変わっています')


def check(order, root, action, write_files=(), command=None, manifest=None):
    require(action != 'experiment', '最小版では数値実験は本人が起動します')
    require(action in {'implement', 'test', 'slides', 'present'}, '未対応actionです')
    root = Path(root).resolve()
    digest = scope_hash(order, root)
    scope = order['scope']
    operation_name = 'slides' if action == 'present' else action
    require(operation_name in scope['operations'], 'この工程は作業票の対象外です')
    operation = scope['operations'][operation_name]
    require(not scope['unresolved'], '未決事項があります。該当する相談・仕様確認へ戻してください')
    require(isinstance(order['state'], dict) and order['state'].get('phase') == 'ready',
            'readyではありません。差戻し理由と承認を確認してください')
    require(isinstance(order['approvals'], dict), '承認記録の型が不正です')
    receipt_valid(order['approvals'].get('slides' if action == 'present' else action), digest)
    require(action != 'test' or command is not None, 'テストは実際のargvを指定してください')
    require(action != 'implement' or bool(write_files), '実装は実際の編集先を指定してください')
    require(action != 'slides' or manifest is not None or bool(write_files),
            '描画前は編集先、描画後はmanifestを指定してください')
    require(action != 'present' or (not write_files and command is None),
            '発表用の採用確認は書込・コマンドを許可しません')
    for name in write_files:
        write_path(root, name)
        require(name in operation['write_files'], '書込対象がこの工程の承認範囲にありません')
    if command is not None:
        require(action in {'test', 'slides'} and command in operation['commands'],
                'コマンドが承認範囲にありません')
    if action in {'slides', 'present'}:
        require(scope['presentation'] is not None, '掲載計画がありません')
        if manifest is not None:
            check_manifest(manifest, scope, root)
        if action == 'present':
            require(manifest is not None, '発表用の採用には成果物manifestが必要です')
            receipt = order.get('presentation_acceptance')
            receipt_valid(receipt, digest)
            require(receipt.get('explanation_confirmed') is True,
                    '本人の説明確認が未了です。相談または構成確認へ戻してください')
            require(receipt.get('manifest_hash') == json_hash(manifest), '説明確認後に成果物が変わっています')
    else:
        require(manifest is None, 'このactionではスライドmanifestを扱いません')
    return {'status': 'RECORD_CHECK_PASS', 'scope_hash': digest, 'action': action,
            'warning': '記録の整合性のみ。本人性・実画像内容・実効権限は別途確認。操作は実行しません。'}


def summarize_usage(records):
    require(isinstance(records, list) and all(isinstance(r, dict) for r in records), '利用量記録が不正です')
    values = [r.get('tokens') for r in records]
    require(all(v is None or (type(v) is int and v >= 0) for v in values), 'tokensは非負整数またはnullです')
    unknown = sum(v is None for v in values)
    known = sum(v for v in values if v is not None)
    return {'calls': len(records), 'known_tokens': known,
            'unavailable_token_records': unknown, 'total_tokens': None if unknown else known,
            'requested_models': [r.get('requested_model') for r in records],
            'effective_models': [r.get('effective_model') for r in records]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='operation', required=True)
    for operation in ('digest', 'check'):
        p = sub.add_parser(operation)
        p.add_argument('order', type=Path)
        p.add_argument('--root', type=Path, default=Path.cwd())
        if operation == 'check':
            p.add_argument('--action', required=True, choices=['implement', 'test', 'slides', 'present', 'experiment'])
            p.add_argument('--write', action='append', default=[])
            p.add_argument('--command-json', help='照合するargv JSON。実行しません')
            p.add_argument('--manifest', type=Path)
    p = sub.add_parser('manifest-digest')
    p.add_argument('manifest', type=Path)
    p = sub.add_parser('usage')
    p.add_argument('log', type=Path, help='JSON配列の利用量記録')
    args = parser.parse_args()
    try:
        if args.operation == 'usage':
            result = summarize_usage(read_json(args.log))
        elif args.operation == 'manifest-digest':
            result = {'manifest_hash': json_hash(read_json(args.manifest))}
        else:
            order = read_json(args.order)
            if args.operation == 'digest':
                result = {'scope_hash': scope_hash(order, args.root), 'approval_granted': False}
            else:
                result = check(order, args.root, args.action, args.write,
                               json.loads(args.command_json) if args.command_json else None,
                               read_json(args.manifest) if args.manifest else None)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (Rejected, OSError, ValueError, TypeError, KeyError) as exc:
        print(json.dumps({'status': 'REJECTED', 'reason': str(exc)}, ensure_ascii=False))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
