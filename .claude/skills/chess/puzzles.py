#!/usr/bin/env python3
"""Chess puzzle trainer backed by the Lichess CC0 puzzle database.

Subcommands:
  puzzles.py next   [--min-rating N] [--flip-off]   -> serve a random unsolved puzzle
  puzzles.py check  "<your line>"                    -> grade your line, update Elo
  puzzles.py status                                  -> show Elo + counts
  puzzles.py build  [--min-rating N] [--limit N]     -> (re)build the cached slice

State + the cached puzzle slice live under ~/.cache/chess-puzzles/ (never committed).
On first `next` the slice is streamed from database.lichess.org and filtered to
rating >= min-rating, stopping once `limit` puzzles are collected.

Lichess row: PuzzleId,FEN,Moves,Rating,RatingDeviation,Popularity,NbPlays,Themes,GameUrl,OpeningTags
The FEN is the position *before* the opponent's setup move (Moves[0]); after that
move it is the solver's turn, and the solver plays Moves[1], Moves[3], ... .

Run inside: nix-shell -p python3Packages.chess python3Packages.zstandard librsvg
"""
import argparse, csv, datetime, io, json, pathlib, random, sys, urllib.request
import chess

import chess_render as cr  # reuse render_png + helpers from the sibling script

DB_URL = "https://database.lichess.org/lichess_db_puzzle.csv.zst"
CACHE = pathlib.Path.home() / ".cache" / "chess-puzzles"
SLICE = CACHE / "puzzles.csv"
STATE = CACHE / "state.json"
DEFAULT_MIN_RATING = 1800
DEFAULT_LIMIT = 50_000
START_ELO = 1500
K_FACTOR = 32
COLS = ["PuzzleId", "FEN", "Moves", "Rating", "RatingDeviation",
        "Popularity", "NbPlays", "Themes", "GameUrl", "OpeningTags"]


# ---------------------------------------------------------------- state I/O
def load_state():
    if STATE.exists():
        return json.loads(STATE.read_text())
    return {"elo": START_ELO, "solved": [], "failed": [],
            "history": [], "current": None}


def save_state(st):
    CACHE.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(st, indent=2))


# ----------------------------------------------------------- slice building
def build_slice(min_rating, limit):
    """Stream the .zst DB, keep the first `limit` puzzles rated >= min_rating."""
    import zstandard
    CACHE.mkdir(parents=True, exist_ok=True)
    print(f"downloading + filtering (rating >= {min_rating}, up to {limit:,})...",
          file=sys.stderr)
    req = urllib.request.Request(DB_URL, headers={"User-Agent": "chess-skill"})
    rows, scanned = [], 0
    with urllib.request.urlopen(req) as resp:
        reader = zstandard.ZstdDecompressor().stream_reader(resp)
        text = io.TextIOWrapper(reader, encoding="utf-8")
        rd = csv.reader(text)
        next(rd, None)  # header
        for row in rd:
            scanned += 1
            if len(row) < 8:
                continue
            try:
                if int(row[3]) >= min_rating:
                    rows.append(row)
            except ValueError:
                continue
            if len(rows) >= limit:
                break
            if scanned % 100_000 == 0:
                print(f"  scanned {scanned:,}, kept {len(rows):,}", file=sys.stderr)
    with SLICE.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(COLS)
        w.writerows(rows)
    print(f"cached {len(rows):,} puzzles -> {SLICE}", file=sys.stderr)
    return rows


def load_slice():
    with SLICE.open(newline="") as f:
        rd = csv.DictReader(f)
        return list(rd)


# ------------------------------------------------------------- puzzle logic
def solver_view(fen, moves_uci):
    """Apply the opponent's setup move; return (board, setup_move, solution_uci)."""
    board = chess.Board(fen)
    setup = chess.Move.from_uci(moves_uci[0])
    board.push(setup)
    return board, setup, moves_uci[1:]


def tokenize(text):
    """Split a user line into move tokens, stripping move numbers and ellipses."""
    out = []
    for tok in text.replace(",", " ").split():
        tok = tok.strip().lstrip("0123456789.").strip()
        if tok and tok != "...":
            out.append(tok)
    return out


def grade(board, solution_uci, tokens):
    """Walk the user's solver moves against the solution, parsing each token in
    the live position and auto-playing the opponent's recorded replies between
    them. Returns (verdict, solver_plies_done); verdict is 'solved' | 'wrong'
    | 'incomplete'. Raises ValueError on an unparseable token."""
    b = board.copy()
    sol = [chess.Move.from_uci(u) for u in solution_uci]
    si = 0          # index into sol (even = solver move, odd = opponent reply)
    for tok in tokens:
        if si >= len(sol):
            break
        try:
            um = b.parse_san(tok)
        except ValueError:
            try:
                um = b.parse_uci(tok.lower())
            except ValueError:
                raise ValueError(f"unparseable move: {tok!r}")
        ok = (um == sol[si])
        if not ok and si == len(sol) - 1:   # accept any mate at the final move
            t = b.copy(); t.push(um)
            ok = t.is_checkmate()
        if not ok:
            return "wrong", si
        b.push(um); si += 1
        if si < len(sol):                   # auto-play opponent's reply
            b.push(sol[si]); si += 1
    return ("solved" if si >= len(sol) else "incomplete"), si


def expected_score(ru, rp):
    return 1.0 / (1.0 + 10 ** ((rp - ru) / 400.0))


# ------------------------------------------------------------------ actions
def cmd_next(args):
    st = load_state()
    if not SLICE.exists():
        build_slice(args.min_rating, args.limit)
    pool = load_slice()
    solved = set(st["solved"])
    candidates = [p for p in pool
                  if p["PuzzleId"] not in solved and int(p["Rating"]) >= args.min_rating]
    if not candidates:
        print(json.dumps({"error": "no unsolved puzzles in cache for that rating"}))
        return
    p = random.choice(candidates)
    moves = p["Moves"].split()
    board, setup, solution = solver_view(p["FEN"], moves)
    flip = (board.turn == chess.BLACK) and not args.flip_off
    out = CACHE / "current.png"
    cr.render_png(board, str(out), flip, lastmove=setup)  # no eval, no spoiler arrows
    st["current"] = {
        "id": p["PuzzleId"], "fen": p["FEN"], "moves": moves,
        "rating": int(p["Rating"]), "themes": p["Themes"],
        "solver_fen": board.fen(), "solution": solution,
        "side": "White" if board.turn else "Black",
        "started": datetime.datetime.now().isoformat(timespec="seconds"),
    }
    save_state(st)
    print(json.dumps({
        "id": p["PuzzleId"], "rating": int(p["Rating"]),
        "side_to_move": "White" if board.turn else "Black",
        "fen": board.fen(), "image": str(out.resolve()),
        "your_elo": round(st["elo"]), "solved_count": len(st["solved"]),
        "n_solver_moves": (len(solution) + 1) // 2,
    }, indent=2))


def cmd_check(args):
    st = load_state()
    cur = st.get("current")
    if not cur:
        print(json.dumps({"error": "no active puzzle; run `next` first"})); return
    board = chess.Board(cur["solver_fen"])
    try:
        verdict, _ = grade(board, cur["solution"], tokenize(args.line))
    except ValueError as e:
        print(json.dumps({"error": str(e)})); return

    result = {"id": cur["id"], "rating": cur["rating"], "verdict": verdict}
    if verdict == "incomplete":   # correct so far — reveal nothing, keep puzzle active
        result["note"] = "correct so far — give the full line"
        print(json.dumps(result, indent=2)); return

    sol_san = []  # full solution in SAN, from the solver position (terminal only)
    b = chess.Board(cur["solver_fen"])
    for u in cur["solution"]:
        mv = chess.Move.from_uci(u); sol_san.append(b.san(mv)); b.push(mv)
    result["themes"] = cur["themes"]
    result["solution"] = sol_san

    success = (verdict == "solved")
    rp, ru = cur["rating"], st["elo"]
    delta = K_FACTOR * ((1.0 if success else 0.0) - expected_score(ru, rp))
    st["elo"] = ru + delta
    (st["solved"] if success else st["failed"]).append(cur["id"])
    st["history"].append({"id": cur["id"], "rating": rp, "result": verdict,
                          "elo_after": round(st["elo"]),
                          "at": datetime.datetime.now().isoformat(timespec="seconds")})
    # render the solved-out position with the full line on the board
    bb = chess.Board(cur["solver_fen"]); last = None
    for u in cur["solution"]:
        last = chess.Move.from_uci(u); bb.push(last)
    flip = (chess.Board(cur["solver_fen"]).turn == chess.BLACK)
    out = CACHE / "solution.png"
    cr.render_png(bb, str(out), flip, lastmove=last)
    st["current"] = None
    save_state(st)
    result.update({"elo_before": round(ru), "elo_after": round(st["elo"]),
                   "elo_delta": round(delta, 1), "image": str(out.resolve())})
    print(json.dumps(result, indent=2))


def cmd_status(args):
    st = load_state()
    print(json.dumps({
        "elo": round(st["elo"]), "solved": len(st["solved"]),
        "failed": len(st["failed"]),
        "cached": SLICE.exists() and sum(1 for _ in SLICE.open()) - 1 or 0,
        "active_puzzle": (st["current"] or {}).get("id"),
    }, indent=2))


def cmd_build(args):
    build_slice(args.min_rating, args.limit)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    n = sub.add_parser("next"); n.set_defaults(fn=cmd_next)
    n.add_argument("--min-rating", type=int, default=DEFAULT_MIN_RATING)
    n.add_argument("--limit", type=int, default=DEFAULT_LIMIT)
    n.add_argument("--flip-off", action="store_true",
                   help="keep White at bottom even when the solver is Black")
    c = sub.add_parser("check"); c.set_defaults(fn=cmd_check)
    c.add_argument("line", help="your solving line, SAN or UCI (e.g. 'Qxh7+ Kxh7 Rh3#')")
    s = sub.add_parser("status"); s.set_defaults(fn=cmd_status)
    b = sub.add_parser("build"); b.set_defaults(fn=cmd_build)
    b.add_argument("--min-rating", type=int, default=DEFAULT_MIN_RATING)
    b.add_argument("--limit", type=int, default=DEFAULT_LIMIT)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
