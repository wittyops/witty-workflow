#!/bin/bash
# BookStack API content provisioner — create a book with chapters and pages.
#
# Usage:
#   BS_TOKEN="<id>:<secret>" ./provision-bookstack.sh
#
# Or set BS_TOKEN from Vaultwarden before running:
#   BS_TOKEN=$(bw get item "BookStack - API Token" --session "$(cat ~/.bw_session)" \
#     | python3 -c "import sys,json; item=json.load(sys.stdin); [print(f['value']) for f in item.get('fields',[]) if 'API-TOKEN' in f['name']]")

set -euo pipefail

BS_URL="https://wiki.wittycomp.com"
BS_TOKEN="${BS_TOKEN:?Set BS_TOKEN=<id>:<secret>}"

bs_create_book() {
    local name="$1" desc="${2:-}"
    curl -sf -X POST "$BS_URL/api/books" \
        -H "Authorization: Token $BS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\": $(echo "$name" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"), \"description\": $(echo "$desc" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))")}" \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])"
}

bs_create_chapter() {
    local book_id="$1" name="$2" desc="${3:-}"
    curl -sf -X POST "$BS_URL/api/chapters" \
        -H "Authorization: Token $BS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"book_id\": $book_id, \"name\": $(echo "$name" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"), \"description\": \"\"}" \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])"
}

bs_create_page() {
    local book_id="$1" chapter_id="$2" name="$3" content="$4"
    curl -sf -X POST "$BS_URL/api/pages" \
        -H "Authorization: Token $BS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"book_id\": $book_id,
            \"chapter_id\": $chapter_id,
            \"name\": $(echo "$name" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),
            \"markdown\": $(echo "$content" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
        }" | python3 -c "import sys,json; r=json.load(sys.stdin); print('Page:', r.get('id'), r.get('name',''))"
}

# --- Example: create a new book ---

BOOK_ID=$(bs_create_book "Example Guide" "A sample book created via API")
echo "Created book ID: $BOOK_ID"

CH1=$(bs_create_chapter "$BOOK_ID" "Introduction")
echo "Created chapter ID: $CH1"

bs_create_page "$BOOK_ID" "$CH1" "Overview" "# Overview

This page was created programmatically via the BookStack API.

See [BookStack API docs](https://www.bookstackapp.com/docs/api/) for full reference.
"

echo "Done. View at: $BS_URL"
