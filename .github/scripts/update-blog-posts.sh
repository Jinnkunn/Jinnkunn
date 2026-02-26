#!/usr/bin/env bash
set -euo pipefail

RSS_URL="${RSS_URL:-https://jinkunchen.com/blog.rss}"
README_PATH="${README_PATH:-README.md}"
POST_LIMIT="${POST_LIMIT:-3}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

posts_file="$tmp_dir/posts.md"

curl -fsSL "$RSS_URL" | tr '\n' ' ' | perl -0ne '
  my $limit = $ENV{"POST_LIMIT"} // 3;
  my $count = 0;
  while (/<item>\s*<title><!\[CDATA\[(.*?)\]\]><\/title>\s*<link>(.*?)<\/link>/g) {
    print "- [$1]($2)\n";
    $count++;
    last if $count >= $limit;
  }
' > "$posts_file"

if [[ ! -s "$posts_file" ]]; then
  echo "Failed to parse any blog posts from ${RSS_URL}" >&2
  exit 1
fi

awk \
  -v start='<!-- BLOG-POST-LIST:START -->' \
  -v end='<!-- BLOG-POST-LIST:END -->' \
  -v posts_file="$posts_file" \
  '
BEGIN {
  while ((getline line < posts_file) > 0) {
    posts = posts line "\n"
  }
}
$0 == start {
  found_start = 1
  print
  printf "%s", posts
  in_block = 1
  next
}
$0 == end {
  found_end = 1
  in_block = 0
  print
  next
}
!in_block { print }
END {
  if (!found_start || !found_end) {
    exit 2
  }
}
' "$README_PATH" > "$tmp_dir/README.md"

mv "$tmp_dir/README.md" "$README_PATH"
