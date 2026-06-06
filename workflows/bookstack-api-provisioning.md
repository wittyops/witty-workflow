# Workflow: Provision BookStack Content via API

## Why

BookStack at `wiki.wittycomp.com` uses a REST API that lets you create books, chapters, and pages programmatically — avoiding tedious manual clicking for structured documentation. This is especially useful for bulk-importing content from markdown, provisioning from scripts, or seeding a new install.

---

## Infrastructure

| Component | Detail |
|-----------|--------|
| URL | `https://wiki.wittycomp.com` |
| API base | `https://wiki.wittycomp.com/api/` |
| API token | Vaultwarden: "BookStack - API Token" (format: `<id>:<secret>`) |
| Container | `wn-bookstack-01` at `10.10.30.55` |

---

## Authentication

All API calls use `Authorization: Token <id>:<secret>` header.

```bash
BS_TOKEN=$(# from Vaultwarden: "BookStack - API Token" field "BOOKSTACK-API-TOKEN")
# Format: "e6daf57d...:abc123..."

curl -s -H "Authorization: Token $BS_TOKEN" https://wiki.wittycomp.com/api/books | python3 -m json.tool
```

---

## Content Hierarchy

```
Book
└── Chapter
    └── Page
```

Books are top-level containers. Chapters are optional groupings within a book. Pages are the actual content, accepting HTML or Markdown body.

---

## Create a Book

```bash
curl -s -X POST https://wiki.wittycomp.com/api/books \
  -H "Authorization: Token $BS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "My Book", "description": "One-line description"}'
# Returns: {"id": 1, "name": "My Book", ...}
BOOK_ID=1
```

## Create a Chapter

```bash
curl -s -X POST https://wiki.wittycomp.com/api/chapters \
  -H "Authorization: Token $BS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"book_id\": $BOOK_ID, \"name\": \"Chapter Title\", \"description\": \"\"}"
# Returns: {"id": 5, ...}
CHAPTER_ID=5
```

## Create a Page

```bash
# Using Markdown body:
curl -s -X POST https://wiki.wittycomp.com/api/pages \
  -H "Authorization: Token $BS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"book_id\": $BOOK_ID,
    \"chapter_id\": $CHAPTER_ID,
    \"name\": \"Page Title\",
    \"markdown\": \"# Heading\n\nContent here.\"
  }"
```

---

## Bulk Provisioning Pattern

For large books, write a shell or Python script that iterates a data structure. See [scripts/provision-bookstack.sh](../scripts/provision-bookstack.sh) for a working example.

Pattern:
1. Create book → save `$BOOK_ID`
2. For each chapter: create chapter → save `$CHAPTER_ID`
3. For each page in chapter: create page with `book_id` + `chapter_id`

---

## List Existing Content

```bash
# Books:
curl -s -H "Authorization: Token $BS_TOKEN" https://wiki.wittycomp.com/api/books | python3 -c "import sys,json; [print(b['id'], b['name']) for b in json.load(sys.stdin)['data']]"

# Pages:
curl -s -H "Authorization: Token $BS_TOKEN" "https://wiki.wittycomp.com/api/pages?count=50" | python3 -c "import sys,json; [print(p['id'], p['book_id'], p['name']) for p in json.load(sys.stdin)['data']]"
```

---

## Books Created So Far

| ID | Book | Chapters |
|----|------|---------|
| 1 | Cooklang Language Guide | Introduction, Ingredients, Cookware, Timers, Comments & Metadata, Tools |
| 2 | Markdown Language Guide | Introduction, Core Syntax, Extended Syntax, GFM, Best Practices |
