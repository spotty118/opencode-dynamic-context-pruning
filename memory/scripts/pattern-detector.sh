#!/usr/bin/env bash

###############################################################################
# Pattern Detection Utility
#
# Analyzes conversation summaries to detect recurring patterns, conventions,
# and architectural decisions. Can be run standalone or called by agents.
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MEMORY_DIR="${HOME}/.config/claude/dcp/memory"
SESSIONS_DIR="${MEMORY_DIR}/sessions"
PROJECTS_DIR="${MEMORY_DIR}/projects"

# Default options
MIN_PATTERN_OCCURRENCES=3
MIN_CONFIDENCE=0.7
OUTPUT_FORMAT="json"
ANALYSIS_SCOPE="all"

###############################################################################
# Helper Functions
###############################################################################

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Detect patterns in conversation summaries and code.

OPTIONS:
    -s, --scope SCOPE       Analysis scope: all, session, recent (default: all)
    -t, --type TYPE         Pattern type: architectural, naming, tech-stack, all (default: all)
    -m, --min-occurrences N Minimum pattern occurrences (default: 3)
    -c, --min-confidence N  Minimum confidence score 0-1 (default: 0.7)
    -o, --output FORMAT     Output format: json, markdown, text (default: json)
    -d, --session-id ID     Analyze specific session only
    -h, --help              Show this help message

EXAMPLES:
    # Detect all patterns with default settings
    $0

    # Detect architectural patterns only
    $0 --type architectural

    # Analyze recent sessions only
    $0 --scope recent --min-occurrences 2

    # Generate markdown report
    $0 --output markdown

EOF
    exit 0
}

###############################################################################
# Pattern Detection Functions
###############################################################################

# Count pattern occurrences across summaries
count_pattern_occurrences() {
    local pattern_type="$1"
    local pattern_value="$2"
    local count=0

    # Search all summary files
    while IFS= read -r summary_file; do
        if grep -qi "$pattern_value" "$summary_file" 2>/dev/null; then
            ((count++))
        fi
    done < <(find "$SESSIONS_DIR" -name "*.json" 2>/dev/null || true)

    echo "$count"
}

# Detect architectural patterns
detect_architectural_patterns() {
    local patterns_found=()

    print_info "Detecting architectural patterns..."

    # Define common architectural patterns to look for
    local -A arch_patterns=(
        ["state_management_react_context"]="React Context|createContext|Context.Provider"
        ["state_management_redux"]="Redux|createStore|useDispatch|useSelector"
        ["state_management_zustand"]="zustand|create.*store"
        ["api_rest"]="REST|express.*route|@Get|@Post"
        ["api_graphql"]="GraphQL|gql|useQuery|useMutation"
        ["auth_jwt"]="JWT|jsonwebtoken|sign.*token|verify.*token"
        ["auth_session"]="express-session|session.*cookie"
        ["db_postgresql"]="PostgreSQL|pg|postgres"
        ["db_mongodb"]="MongoDB|mongoose|MongoClient"
        ["testing_jest"]="Jest|describe.*test|expect"
        ["testing_vitest"]="Vitest|vitest"
        ["styling_tailwind"]="Tailwind|tailwindcss|className.*['\"].*:"
        ["styling_css_modules"]="CSS Modules|module.css|styles\\."
    )

    # Search for each pattern
    for pattern_key in "${!arch_patterns[@]}"; do
        local pattern_regex="${arch_patterns[$pattern_key]}"
        local occurrences=0

        while IFS= read -r summary_file; do
            if grep -Pqi "$pattern_regex" "$summary_file" 2>/dev/null; then
                ((occurrences++))
            fi
        done < <(find "$SESSIONS_DIR" -name "*.json" 2>/dev/null || true)

        if [[ $occurrences -ge $MIN_PATTERN_OCCURRENCES ]]; then
            local confidence=$(awk "BEGIN {printf \"%.2f\", $occurrences / 10.0}")
            if (( $(awk "BEGIN {print ($confidence >= $MIN_CONFIDENCE)}") )); then
                patterns_found+=("$pattern_key:$occurrences:$confidence")
            fi
        fi
    done

    printf '%s\n' "${patterns_found[@]}"
}

# Detect naming conventions
detect_naming_conventions() {
    local conventions_found=()

    print_info "Detecting naming conventions..."

    # Look for file naming patterns in files_modified
    local kebab_case_count=0
    local camel_case_count=0
    local pascal_case_count=0

    while IFS= read -r summary_file; do
        # Extract file paths and analyze naming
        if command -v jq &>/dev/null; then
            while IFS= read -r filepath; do
                local filename=$(basename "$filepath")
                filename="${filename%.*}"  # Remove extension

                # Check naming pattern
                if [[ "$filename" =~ ^[a-z]+(-[a-z]+)*$ ]]; then
                    ((kebab_case_count++))
                elif [[ "$filename" =~ ^[a-z][a-zA-Z0-9]*$ ]]; then
                    ((camel_case_count++))
                elif [[ "$filename" =~ ^[A-Z][a-zA-Z0-9]*$ ]]; then
                    ((pascal_case_count++))
                fi
            done < <(jq -r '.summary.files_modified[]?.path // empty' "$summary_file" 2>/dev/null || true)
        fi
    done < <(find "$SESSIONS_DIR" -name "*.json" 2>/dev/null || true)

    # Determine dominant convention
    local total=$((kebab_case_count + camel_case_count + pascal_case_count))
    if [[ $total -gt 0 ]]; then
        if [[ $kebab_case_count -gt $camel_case_count ]] && [[ $kebab_case_count -gt $pascal_case_count ]]; then
            local confidence=$(awk "BEGIN {printf \"%.2f\", $kebab_case_count / $total}")
            conventions_found+=("file_naming_kebab_case:$kebab_case_count:$confidence")
        elif [[ $pascal_case_count -gt $kebab_case_count ]] && [[ $pascal_case_count -gt $camel_case_count ]]; then
            local confidence=$(awk "BEGIN {printf \"%.2f\", $pascal_case_count / $total}")
            conventions_found+=("file_naming_PascalCase:$pascal_case_count:$confidence")
        elif [[ $camel_case_count -ge $MIN_PATTERN_OCCURRENCES ]]; then
            local confidence=$(awk "BEGIN {printf \"%.2f\", $camel_case_count / $total}")
            conventions_found+=("file_naming_camelCase:$camel_case_count:$confidence")
        fi
    fi

    printf '%s\n' "${conventions_found[@]}"
}

# Detect technology stack
detect_tech_stack() {
    local tech_found=()

    print_info "Detecting technology stack..."

    # Define technologies to look for
    local -A technologies=(
        ["react"]="React|react|useState|useEffect"
        ["vue"]="Vue|vue|createApp"
        ["angular"]="Angular|@angular"
        ["express"]="Express|express\\(\\)"
        ["fastify"]="Fastify|fastify"
        ["next"]="Next.js|next/|getServerSideProps"
        ["typescript"]="TypeScript|interface|type.*="
        ["python"]="Python|def |import "
        ["node"]="Node.js|node|require\\("
    )

    for tech_key in "${!technologies[@]}"; do
        local tech_regex="${technologies[$tech_key]}"
        local occurrences=0

        while IFS= read -r summary_file; do
            if grep -Pqi "$tech_regex" "$summary_file" 2>/dev/null; then
                ((occurrences++))
            fi
        done < <(find "$SESSIONS_DIR" -name "*.json" 2>/dev/null || true)

        if [[ $occurrences -ge $MIN_PATTERN_OCCURRENCES ]]; then
            local confidence=$(awk "BEGIN {printf \"%.2f\", ($occurrences * 0.1)}")
            if (( $(awk "BEGIN {print ($confidence >= $MIN_CONFIDENCE)}") )); then
                tech_found+=("$tech_key:$occurrences:$confidence")
            fi
        fi
    done

    printf '%s\n' "${tech_found[@]}"
}

###############################################################################
# Output Formatters
###############################################################################

format_json_output() {
    local arch_patterns=("$@")
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat <<EOF
{
  "analysis_timestamp": "$timestamp",
  "min_occurrences": $MIN_PATTERN_OCCURRENCES,
  "min_confidence": $MIN_CONFIDENCE,
  "patterns": {
    "architectural": [
EOF

    local first=true
    for pattern in "${arch_patterns[@]}"; do
        IFS=':' read -r name occurrences confidence <<< "$pattern"
        [[ "$first" == "true" ]] && first=false || echo ","
        cat <<EOF
      {
        "pattern": "$name",
        "occurrences": $occurrences,
        "confidence": $confidence
      }
EOF
    done

    cat <<EOF

    ]
  }
}
EOF
}

format_markdown_output() {
    local arch_patterns=("$@")
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat <<EOF
# Pattern Detection Report

**Generated**: $timestamp
**Min Occurrences**: $MIN_PATTERN_OCCURRENCES
**Min Confidence**: $MIN_CONFIDENCE

## Architectural Patterns

| Pattern | Occurrences | Confidence |
|---------|-------------|------------|
EOF

    for pattern in "${arch_patterns[@]}"; do
        IFS=':' read -r name occurrences confidence <<< "$pattern"
        printf "| %s | %d | %.2f |\n" "$name" "$occurrences" "$confidence"
    done

    cat <<EOF

## Recommendations

Based on the patterns detected:

EOF

    for pattern in "${arch_patterns[@]}"; do
        IFS=':' read -r name occurrences confidence <<< "$pattern"
        echo "- **$name**: Used in $occurrences sessions (${confidence} confidence) - Consider this an established pattern"
    done
}

###############################################################################
# Main
###############################################################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--scope)
                ANALYSIS_SCOPE="$2"
                shift 2
                ;;
            -t|--type)
                PATTERN_TYPE="$2"
                shift 2
                ;;
            -m|--min-occurrences)
                MIN_PATTERN_OCCURRENCES="$2"
                shift 2
                ;;
            -c|--min-confidence)
                MIN_CONFIDENCE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -d|--session-id)
                SESSION_ID="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Check if memory directory exists
    if [[ ! -d "$SESSIONS_DIR" ]]; then
        print_error "Memory directory not found: $SESSIONS_DIR"
        print_info "Run the memory system setup first: cd memory && ./install.sh"
        exit 1
    fi

    # Count total summaries
    local total_summaries=$(find "$SESSIONS_DIR" -name "*.json" 2>/dev/null | wc -l)
    if [[ $total_summaries -eq 0 ]]; then
        print_warning "No summaries found in memory system"
        print_info "Patterns will be detected as you accumulate conversation summaries"
        exit 0
    fi

    print_info "Analyzing $total_summaries summaries..."

    # Detect patterns
    mapfile -t arch_patterns < <(detect_architectural_patterns)
    mapfile -t naming_conventions < <(detect_naming_conventions)
    mapfile -t tech_stack < <(detect_tech_stack)

    # Output results
    case $OUTPUT_FORMAT in
        json)
            format_json_output "${arch_patterns[@]}"
            ;;
        markdown)
            format_markdown_output "${arch_patterns[@]}"
            ;;
        text)
            echo "Architectural Patterns:"
            printf '%s\n' "${arch_patterns[@]}"
            echo ""
            echo "Naming Conventions:"
            printf '%s\n' "${naming_conventions[@]}"
            echo ""
            echo "Technology Stack:"
            printf '%s\n' "${tech_stack[@]}"
            ;;
        *)
            print_error "Unknown output format: $OUTPUT_FORMAT"
            exit 1
            ;;
    esac

    print_success "Pattern detection complete"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
