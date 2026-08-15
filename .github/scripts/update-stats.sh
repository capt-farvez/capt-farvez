#!/usr/bin/env bash
# Refreshes the stat card SVGs in assets/, trying each source in order.
# A card is only overwritten by a fetch that passes validation, so a dead
# source can never replace a good image with an error card.
#
# When PAT_1 is set (repo Actions secret, or exported locally), the two
# github-readme-stats cards are rendered by a local instance using that
# token, so ALL-TIME private commits and private-repo languages are
# included. Without PAT_1 it falls back to public mirrors (public data,
# private counts limited to the last 12 months).
set -u

OUT="assets"
COMMON="username=capt-farvez&theme=tokyonight&hide_border=true"

fetch() {
  local target="$1"; shift
  local tmp url attempt code size
  tmp="$(mktemp)"
  for url in "$@"; do
    for attempt in 1 2 3; do
      code="$(curl -sL -o "$tmp" -w '%{http_code}' --max-time 60 "$url" || echo 000)"
      size="$(wc -c < "$tmp")"
      if [ "$code" = 200 ] && [ "$size" -gt 3000 ] && grep -q "<svg" "$tmp" \
         && ! grep -qiE "something went wrong|max(imum)? retries|rate limit" "$tmp"; then
        mv "$tmp" "$OUT/$target"
        echo "updated $target ($size bytes) from $url"
        return 0
      fi
      sleep 5
    done
  done
  rm -f "$tmp"
  echo "WARN: all sources failed for $target — keeping previous image"
}

# bg_color=00000000 makes these two transparent — they are composed into a
# single shared-background card by merge-cards.py below.
STATS_PATH="api?${COMMON}&show_icons=true&include_all_commits=true&count_private=true&show=reviews&rank_icon=github&bg_color=00000000"
LANGS_PATH="api/top-langs/?${COMMON}&layout=compact&langs_count=8&bg_color=00000000"
# Ordered by preference: healthiest community mirrors first, then the
# official (rate-limited) instance, then remaining mirrors.
HOSTS="github-readme-stats-salesp07.vercel.app github-readme-stats.vercel.app github-readme-stats-eight-theta.vercel.app grs-stats.vercel.app github-readme-stats-sigma-five.vercel.app"

stats_urls=()
langs_urls=()
for h in $HOSTS; do
  stats_urls+=("https://$h/$STATS_PATH")
  langs_urls+=("https://$h/$LANGS_PATH")
done

LOCAL_SERVER=""
if [ -n "${PAT_1:-}" ]; then
  echo "PAT_1 present — starting local github-readme-stats renderer"
  GRS_DIR="${GRS_DIR:-/tmp/grs}"
  if [ ! -d "$GRS_DIR/node_modules" ]; then
    git clone --depth 1 --quiet https://github.com/anuraghazra/github-readme-stats.git "$GRS_DIR"
    (cd "$GRS_DIR" && npm ci --no-audit --no-fund)
  fi
  (cd "$GRS_DIR" && PAT_1="$PAT_1" node express.js >/tmp/grs-server.log 2>&1 &)
  # Wait until the server accepts connections (any HTTP status will do).
  for _ in $(seq 1 30); do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "http://localhost:9000/" || true)"
    [ "$code" != "000" ] && LOCAL_SERVER=1 && break
    sleep 1
  done
  if [ -n "$LOCAL_SERVER" ]; then
    # Local renderer first; validation still guards against a bad/expired
    # token, in which case the public mirrors take over.
    stats_urls=("http://localhost:9000/$STATS_PATH" "${stats_urls[@]}")
    langs_urls=("http://localhost:9000/$LANGS_PATH" "${langs_urls[@]}")
  else
    echo "WARN: local renderer did not start — using public mirrors"
    cat /tmp/grs-server.log || true
  fi
fi

fetch github-stats.svg   "${stats_urls[@]}"
fetch top-languages.svg  "${langs_urls[@]}"
fetch github-streak.svg  "https://streak-stats.demolab.com/?user=capt-farvez&theme=tokyonight&hide_border=true&background=00000000"

# Trophy card (official instance is disabled — community mirrors only).
# Explicit title selection: the rank=-SECRET filter is broken on these mirrors.
TROPHY_PATH="?username=capt-farvez&theme=tokyonight&no-frame=true&no-bg=true&row=1&column=3&margin-w=8&title=Commits,Repositories,PullRequest"
fetch github-trophies.svg \
  "https://github-trophies.vercel.app/$TROPHY_PATH" \
  "https://profile-trophy.vercel.app/$TROPHY_PATH" \
  "https://github-profile-trophy-one.vercel.app/$TROPHY_PATH"
fetch activity-graph.svg "https://github-readme-activity-graph.vercel.app/graph?username=capt-farvez&bg_color=1a1b27&color=70a5fd&line=bf91f3&point=38bdae&area=true&hide_border=true"

python3 .github/scripts/merge-cards.py

[ -n "$LOCAL_SERVER" ] && pkill -f "node express.js" 2>/dev/null
exit 0
