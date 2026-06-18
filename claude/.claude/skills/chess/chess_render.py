#!/usr/bin/env python3
"""Render a chess position (FEN or PGN) to PNG + structured data.

Usage:
  chess_render.py [--eval] [--depth N] [--flip] [--out PATH] "<FEN or PGN>"
  echo "<FEN or PGN>" | chess_render.py [flags]

Emits JSON to stdout: {fen, opening, moves[], image, eval?, lines?[]}.
Run inside: nix-shell -p stockfish python3Packages.chess librsvg
"""
import argparse, json, pathlib, re, shutil, subprocess, sys, tempfile
import chess, chess.pgn, chess.svg, chess.engine

HERE = pathlib.Path(__file__).parent
ECO = json.loads((HERE / "eco.json").read_text())
PV_PLIES = 8  # plies shown per line in --eval output


def parse_input(text):
    """Return (board, san_moves). Accepts a FEN or PGN movetext/headers."""
    text = text.strip()
    # FEN: first line is 8 ranks separated by '/'
    first = text.splitlines()[0].strip() if text else ""
    if re.match(r"^([rnbqkpRNBQKP1-8]+/){7}[rnbqkpRNBQKP1-8]+(\s|$)", first):
        return chess.Board(first), []
    game = chess.pgn.read_game(__import__("io").StringIO(text))
    if game is None:
        raise ValueError("could not parse input as FEN or PGN")
    board = game.board()
    moves = []
    for mv in game.mainline_moves():
        moves.append(board.san(mv))
        board.push(mv)
    return board, moves


def to_pgn(moves):
    """SAN list -> '1. e4 e5 2. Nf3 ...' movetext."""
    out = []
    for i, san in enumerate(moves):
        if i % 2 == 0:
            out.append(f"{i//2 + 1}.")
        out.append(san)
    return " ".join(out)


def last_ply(moves):
    """The final half-move, numbered: '8. c3' (White) or '8...O-O' (Black)."""
    if not moves:
        return None
    i = len(moves) - 1
    n = i // 2 + 1
    return f"{n}. {moves[i]}" if i % 2 == 0 else f"{n}...{moves[i]}"


def opening_name(board, root_moves):
    """Longest-prefix opening match over the played positions."""
    if not root_moves:
        return ECO.get(board.epd())
    b = chess.Board()
    name = ECO.get(b.epd())
    for san in root_moves:
        b.push_san(san)
        name = ECO.get(b.epd(), name)
    return name


def eval_bar_svg(frac, text, flip, size, bar_w, pad=8):
    """Lichess-style bar; `frac` = White's win expectation [0,1]. White fills
    from its base (bottom, or top when flipped). The rotated label is placed at
    the *winning* side's outer edge — that side's bar is always >=50%, so the
    text is guaranteed to sit on its colour: dark on White's bar, light on
    Black's."""
    white_h = frac * size
    white_y = 0 if flip else size - white_h
    dark, light = "#312e2b", "#f7f6f5"
    white_wins = frac >= 0.5
    fill = dark if white_wins else light
    cx = bar_w / 2
    if white_wins != flip:                  # winner's edge is the bottom
        cy, angle = size - pad, -90         # read upward from bottom
    else:                                   # winner's edge is the top
        cy, angle = pad, 90                 # read downward from top
    return (
        f'<rect width="{bar_w}" height="{size}" fill="{dark}"/>'
        f'<rect y="{white_y:.1f}" width="{bar_w}" height="{white_h:.1f}" fill="{light}"/>'
        f'<text x="{cx}" y="{cy}" transform="rotate({angle} {cx} {cy})" '
        f'font-family="DejaVu Sans" font-size="13" font-weight="bold" '
        f'text-anchor="start" dominant-baseline="central" fill="{fill}">{text}</text>'
    )


def render_png(board, out, flip, lastmove, size=300, eval_frac=None, eval_text=None):
    svg = chess.svg.board(
        board, size=size, coordinates=True,
        orientation=chess.BLACK if flip else chess.WHITE,
        lastmove=lastmove,
    )
    bar_w = 26 if eval_frac is not None else 0
    bar = (eval_bar_svg(eval_frac, eval_text, flip, size, bar_w)
           if bar_w else "")
    wrapped = (
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'width="{size + bar_w}" height="{size}" '
        f'viewBox="0 0 {size + bar_w} {size}">'
        f'<rect width="100%" height="100%" fill="#fff"/>'
        f'{bar}'
        f'<g transform="translate({bar_w},0)">{svg}</g></svg>'
    )
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as tf:
        tf.write(wrapped)
        svgpath = tf.name
    subprocess.run(["rsvg-convert", "-o", str(out), svgpath], check=True)
    pathlib.Path(svgpath).unlink(missing_ok=True)


def fmt_score(score):
    s = score.white()
    if s.is_mate():
        return f"#{s.mate()}"
    return f"{s.score()/100:+.2f}"


def evaluate(board, depth, multipv=5):
    engine = chess.engine.SimpleEngine.popen_uci(shutil.which("stockfish"))
    try:
        infos = engine.analyse(board, chess.engine.Limit(depth=depth), multipv=multipv)
    finally:
        engine.quit()
    lines = []
    for info in infos:
        b = board.copy()
        pv = []
        for mv in info.get("pv", [])[:PV_PLIES]:
            pv.append(b.san(mv))
            b.push(mv)
        lines.append({"score": fmt_score(info["score"]), "pv": pv})
    best = lines[0]["score"] if lines else None
    # White win expectation [0,1] for the eval bar, via python-chess WDL model.
    frac = 0.5
    if infos:
        frac = infos[0]["score"].white().wdl(ply=board.ply()).expectation()
    return best, lines, frac


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input", nargs="?")
    ap.add_argument("--eval", action="store_true")
    ap.add_argument("--depth", type=int, default=18)
    ap.add_argument("--flip", action="store_true")
    ap.add_argument("--out", default=str(pathlib.Path(tempfile.gettempdir()) / "chess.png"))
    args = ap.parse_args()

    text = args.input if args.input else sys.stdin.read()
    board, moves = parse_input(text)

    eval_frac = eval_text = best = lines = None
    if args.eval:
        best, lines, eval_frac = evaluate(board, args.depth)
        eval_text = best

    lastmove = board.peek() if board.move_stack else None
    render_png(board, args.out, args.flip, lastmove,
               eval_frac=eval_frac, eval_text=eval_text)

    result = {
        "fen": board.fen(),
        "turn": "White" if board.turn else "Black",
        "opening": opening_name(board, moves),
        "moves": moves,
        "pgn": to_pgn(moves),
        "last_ply": last_ply(moves),
        "image": str(pathlib.Path(args.out).resolve()),
    }
    if args.eval:
        result["eval"] = best
        result["lines"] = lines
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
