$1 ~ /^\$SYS\/broker\/connection\// {
  split($1, p, "/")
  h = p[4]
  sub(/-bridge$/, "", h)
  up[h] = $2
  next
}
$2 == "held" && $1 != self {
  n = split($1, p, "/")
  held[n == 3 ? hub : p[1]] = 1
}
END {
  for (h in held)
    if (h == hub || up[h] == "1") print h
}
