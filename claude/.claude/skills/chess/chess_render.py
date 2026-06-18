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


def render_png(board, out, flip, lastmove, size=300, pad=0):
    svg = chess.svg.board(
        board, size=size, coordinates=True,
        orientation=chess.BLACK if flip else chess.WHITE,
        lastmove=lastmove,
    )
    # Wrap with `pad` px of white margin. Canvas is sized from the render
    # `size` (px), not the board's internal viewBox units.
    side = size + 2 * pad
    wrapped = (
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'width="{side}" height="{side}" viewBox="0 0 {side} {side}">'
        f'<rect width="100%" height="100%" fill="#fff"/>'
        f'<g transform="translate({pad},{pad})">{svg}</g></svg>'
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
        for mv in info.get("pv", []):
            pv.append(b.san(mv))
            b.push(mv)
        lines.append({"score": fmt_score(info["score"]), "pv": pv})
    best = lines[0]["score"] if lines else None
    return best, lines


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

    lastmove = board.peek() if board.move_stack else None
    render_png(board, args.out, args.flip, lastmove)

    result = {
        "fen": board.fen(),
        "opening": opening_name(board, moves),
        "moves": moves,
        "pgn": to_pgn(moves),
        "image": str(pathlib.Path(args.out).resolve()),
    }
    if args.eval:
        best, lines = evaluate(board, args.depth)
        result["eval"] = best
        result["lines"] = lines
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
