#!/bin/bash

SCRIPT_PATH="$0"
SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.0.0"
FILE_REGEXP="^([^:~@]+)(~([^:@]+))?(:([^@]+))?(@(.+))?$"
PG_UPDATE_SCRIPT_FILENAME_REGEXP="^([-[:alpha:]][[:alnum:]_]+[[:alnum:]])--(([0-9]+)\.([0-9]+)\.([0-9]+))--(([0-9]+)\.([0-9]+)\.([0-9]+))\.sql$"
RELEASE_HEADING_TEMPLATE="## %v – %d"
UNRELEASED_VERSION_HEADING_TEMPLATE="## %v – unreleased"
UNRELEASED_UNVERSIONED_HEADING_TEMPLATE="## Unreleased"
GIT_TAG_TEMPLATE="v%v"

usage() {
    file_args="\e[1;4mfile\e[24;2m[\e[22m\e[1m~\e[4mname\e[22;24m\e[2m]\e[24;2m[\e[22m\e[1m:\e[4mversion\e[22;24m\e[2m][\e[22m\e[1m@\e[4mdate\e[24;2m]\e[22;24m\e[2m…\e[22m"
    expect_arg="\e[22m\e[1m=\e[4mexpect\e[22;24m"
    expect_arg_opt="\e[24;2m[\e[22m$expect_arg\e[2m]\e[22m"

    echo -e "\e[1m$SCRIPT_NAME\e[22m generates (part of) a changelog from special comments in the given SQL file(s).

Usage:
    \e[1m$SCRIPT_NAME\e[22m \e[2m[\e[22m\e[1moption\e[22m\e[2m…]\e[22m $file_args $expect_arg_opt
    \e[1m$SCRIPT_NAME \e[1m-h\e[22m\e[2m|\e[22m\e[1m--help\e[22m
    \e[1m$SCRIPT_NAME \e[1m-V\e[22m\e[2m|\e[22m\e[1m--version\e[22m
    \e[1m$SCRIPT_NAME \e[1m-t\e[22m\e[2m|\e[22m\e[1m--test-self\e[22m

Options & arguments:
    \e[1m-r\e[22m\e[2m|\e[22m\e[1m--release-heading-template\e[22m \e[1;4mtemplate\e[22;24m
        Default: \"\e[1m$RELEASE_HEADING_TEMPLATE\e[22m\"

    \e[1m-u\e[22m\e[2m|\e[22m\e[1m--unreleased-version-heading-template\e[22m \e[1;4mtemplate\e[22;24m
        Default: \"\e[1m$UNRELEASED_VERSION_HEADING_TEMPLATE\e[22m\"

    \e[1m-U\e[22m\e[2m|\e[22m\e[1m--unreleased-unversioned-heading-template\e[22m \e[1;4mtemplate\e[22;24m
        Default: \"\e[1m$UNRELEASED_UNVERSIONED_HEADING_TEMPLATE\e[22m\"

    \e[1m-g\e[22m\e[2m|\e[22m\e[1m--git-tag-template\e[22m \e[1;4mtag-template\e[22;24m
        At which tag to look in Git to determine the release date for a
        specific version, or to construct tag comparison URLs.  Default: \"\e[1m$GIT_TAG_TEMPLATE\e[22m\"

    \e[1m-c\e[22m\e[2m|\e[22m\e[1m--git-tags-comparison-url-template\e[22m \e[1;4mtemplate\e[22;24m
        Example: \e[1mhttps://github.com/bigsmoke/pg_extra_time/compare/%f...%t\e[22m

    \e[1m-p\e[22m\e[2m|\e[22m\e[1m--files-are-postgres-extension-update-scripts\e[22m
        With this option, the version string will be extracted from the
        \e[1mto_version\e[22m part of PostgreSQL extension update script filenames in the
        form of \e[1;4mextension_name--from_version--to_version.sql\e[22;24m.

    \e[1m-v\e[22m\e[2m|\e[22m\e[1m--verbose\e[22m
        Send some verbosity to STDERR.

    $file_args
        At least one SQL file argument must be provided.
        Changelog entries will appear in the order of the files given.

        The filename may optionally be followed by a colon (\e[1m:\e[22m) and a version
        string.

        Use a dash (\e[1m-\e[22m) for filename to read from \e[1mSTDIN\e[22m.

        Additionally, the filename and/or version may be followed by a release
        date, which should be in the form of \e[1mYYYY-MM-DD\e[22m (for example,
        \e[1m2024-07-10\e[22m).

        For testing, while using process substitution, for example, it may be
        desirable to fake a file name.  For that the file path can be followed
        by a \"\e[1m~\e[4mname\e[22;24m\" string (which should go before the version and/or release
        date strings).

    $expect_arg
        The output that is expected from the command can be specified following
        an equals sign (\e[1m=\e[22m).

\e[1m$SCRIPT_NAME\e[22m extracts any part of SQL comment block following a line
starting with \"\e[1mCHANGELOG:\e[22m\" until the end of that comment block.  For
examples, run: \e[1m$SCRIPT_NAME -t\e[22m
"
}

usage_error() {
    echo -e "\e[31m$1\e[0m" >&2
    usage >&2
    exit 2
}

test_self() {
    local retcode;

    "$SCRIPT_PATH" "$@"

    retcode=$?
    if [[ "$retcode" -eq 0 ]]; then
        TESTS_SUCCEEDED=$((TESTS_SUCCEEDED + 1))
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

run_all_self_tests() {
    # These global vars are also used by `test_self()`.
    TESTS_RUN=0
    TESTS_FAILED=0
    TESTS_SUCCEEDED=0

    test_self -:0.0.10@2024-08-16 "=
## [0.0.10] – 2024-08-16

Included

Included
" <<IN
-- CHANGELOG.md:
-- Included
--
-- Included

-- Not included
IN

    test_self -:0.0.10@2024-08-16 "=
## [0.0.10] – 2024-08-16

Part of changelog.

Also part of it.
" <<IN
/**
 * CHANGELOG.md:
 * Part of changelog.
 *
 * Also part of it.
 */

/* Not included */
IN

    test_self -p -~pg_extra_time--0.4.0--0.5.0.sql@2024-08-16 "=
## [0.5.0] – 2024-08-16

Added function to do stuff.
" <<IN
-- CHANGELOG.md:
-- Added function to do stuff.
create function stuff()
IN

    failure_format="\e[1;31m"
    if [[ "$TESTS_FAILED" -eq 0 ]]; then
        failure_format="\e[32m"
    fi
    echo -e "Out of $TESTS_RUN tests, \e[32m$TESTS_SUCCEEDED succeeded$failure_format and $TESTS_FAILED failed\e[0m."

    exit $TESTS_FAILED
}

files_are_postgres_extension_update_scripts=
version_heading_level=2
ARGV=( "$@" )
declare -a files=()
while [[ -n "$1" ]]; do
    case "$1" in
        -h|--help)
            usage
            exit
            ;;
        -V|--version)
            echo "$SCRIPT_VERSION"
            exit
            ;;
        -v|--verbose)
            verbose=quite so
            ;;
        -p|--files-are-postgres-extension-update-scripts)
            files_are_postgres_extension_update_scripts="Yeah, all of em"
            ;;
        -r|--release-heading-template)
            if [[ -z "$2" ]]; then
                usage_error "Missing argument to the \e[1m$1\e[22m option."
            fi
            RELEASE_HEADING_TEMPLATE="$2"
            shift
            ;;
        -u|--unreleased-version-heading-template)
            if [[ -z "$2" ]]; then
                usage_error "Missing argument to the \e[1m$1\e[22m option."
            fi
            UNRELEASED_VERSION_HEADING_TEMPLATE="$2"
            shift
            ;;
        -U|--unreleased-unversioned-heading-template)
            if [[ -z "$2" ]]; then
                usage_error "Missing argument to the \e[1m$1\e[22m option."
            fi
            UNRELEASED_UNVERSIONED_HEADING_TEMPLATE="$2"
            shift
            ;;
        -g|--release-tag-git-template)
            if [[ -z "$2" ]]; then
                usage_error "Missing argument to the \e[1m$1\e[22m option."
            fi
            GIT_TAG_TEMPLATE="$2"
            shift
            ;;
        -c|--git-tags-comparison-url-template)
            if [[ -z "$2" ]]; then
                usage_error "Missing argument to the \e[1m$1\e[22m option."
            fi
            GIT_TAGS_COMPARISON_URL_TEMPLATE="$2"
            shift
            ;;
        -t|--test-self)
            run_all_self_tests
            exit
            ;;
        -|-~*|-:*)
            files+=("$1")
            ;;
        =*)
            expect_out="$(echo "$1" | sed '1 s/^=//')"
            ;;
        -*)
            usage_error "Unknown option: \e[1m$1\e[22m"
            ;;
        *)
            files+=("$1")
            ;;
    esac
    shift
done
if [[ -z "$files" ]]; then
    usage_error "No files given."
fi

SED_SCRIPT_TO_EXTRACT_CHANGELOG_ENTRY='
/^-- CHANGELOG.md:/{:a; n; s/^-- ?//; T; p; ba}
/^\/\*\*/{n; /^ \* CHANGELOG.md:/{n; :b; s/^ \* ?//; /^\//t; p; n; bb}}
'

for file in "${files[@]}"; do
    if [[ ! "$file" =~ $FILE_REGEXP ]]; then
        echo -e "\e[31mThe file argument \e[1m$file\e[22m does not match the regular expression \e[1m$FILE_REGEXP\e[22m\e[0m" >&2
        exit 3
    fi
    update_script_file_path="${BASH_REMATCH[1]}"
    update_script_file_alias="${BASH_REMATCH[3]}"
    update_script_release_version="${BASH_REMATCH[5]}"
    update_script_release_date="${BASH_REMATCH[7]}"

    if [[ -n "$update_script_file_alias" ]]; then
        update_script_filename="$update_script_file_alias"
    else
        update_script_filename="$(basename "$update_script_file_path")"
    fi

    if [[ -n "$files_are_postgres_extension_update_scripts" ]]; then
        if [[ ! "$update_script_filename" =~ $PG_UPDATE_SCRIPT_FILENAME_REGEXP ]]; then
            echo -e "\e[31mThe file name \e[1m$update_script_filename\e[22m does not match the regular expression \e[1m$PG_UPDATE_SCRIPT_FILENAME_REGEXP\e[22m\e[0m" >&2
            exit 3
        fi
        version="${BASH_REMATCH[6]}"
        from_version="${BASH_REMATCH[2]}"
    fi

    if [[ -n "$update_script_release_version" ]]; then
        version="$update_script_release_version"  # Override possibly auto-detected version with explicit version.
    fi

    release_date="$update_script_release_date"
    if [[ -z "$release_date" ]]; then
        git_version_tag_name="$(echo "$GIT_TAG_TEMPLATE" | sed -e "s/%v/$version/")"
        release_date="$(git log -1 --format=%cs "$git_version_tag_name" 2>/dev/null)"
    fi

    if [[ -n "$from_version" ]]; then
        git_from_version_tag_name="$(echo "$GIT_TAG_TEMPLATE" | sed -e "s/%v/$from_version/")"
    fi

    SED_SCRIPT_TO_PROCESS_HEADING_TEMPLATE="s/%v/$version/; s/%d/$release_date/"

    if [[ -n "$version" && -n "$release_date" ]]; then
        heading_template="$RELEASE_HEADING_TEMPLATE"
    elif [[ -n "$version" && -z "$release_date" ]]; then
        heading_template="$UNRELEASED_VERSION_HEADING_TEMPLATE"
    else
        heading_template="$UNRELEASED_UNVERSIONED_HEADING_TEMPLATE"
    fi
    heading="$(echo "$heading_template" | sed -e "$SED_SCRIPT_TO_PROCESS_HEADING_TEMPLATE")"

    in="$(cat "$update_script_file_path")"

    out="$(echo; echo "$heading"; echo; [[ -n "$GIT_TAGS_COMPARISON_URL_TEMPLATE" && -n "$git_from_version_tag_name" ]] && echo -e "[$version]: $(echo -e "$GIT_TAGS_COMPARISON_URL_TEMPLATE"|sed -E "s/%f/$git_from_version_tag_name/; s/%t/$git_version_tag_name/")\n"; echo "$in" | sed -n -E -e "$SED_SCRIPT_TO_EXTRACT_CHANGELOG_ENTRY")"

    if [[ -n "$expect_out" ]]; then
        diff_out="$(diff -t -y -W63 <(echo "$out") <(echo "$expect_out"))"
        diff_ret=$?

        readarray -t in_lines <<< $in
        readarray -t diff_lines <<< $diff_out

        if [[ ${#in_lines[@]} -gt ${#diff_lines[@]} ]]; then
            greatest_line_count=${#in_lines[@]}
            smallest_line_count=${#diff_lines[@]}
        else
            greatest_line_count=${#diff_lines[@]}
            smallest_line_count=${#in_lines[@]}
        fi

        SED_SCRIPT_TO_COLORIZE_DIFF_LINE=$'
# Append extra space.
s/$/                                                                         /;
# Cut off excess space.
s/^(.{63}).*$/\\1/; tb;
:b; s/^(.{30})(   )(.*)$/\e[42;30m\\1\e[0m\\2\e[47;30m\\3\e[0m/; Tc; q;
:c; s/^(.{30})( [^ ] )(.*)$/\e[41;30m\\1\e[49;39m\e[31;1m\\2\e[22;47;30m\\3\e[0m/
'
        echo -e "\e[1m$SCRIPT_NAME ${ARGV[@]::${#ARGV[@]}-1}\e[0m"
        echo
        printf "\e[1m%-30s   %-33s%-30s\e[22m\n" "IN" "STDOUT" "Expected STDOUT"
        for i in $(seq 0 "$greatest_line_count"); do
            diff_line="${diff_lines[$i]}"
            arrow=""
            if [[ $i -eq $(($smallest_line_count / 2)) ]]; then
                arrow="→"
            fi
            if [[ "$i" -lt "${#diff_lines[@]}" ]]; then
                diff_line="$(echo "$diff_line" | sed -E "$SED_SCRIPT_TO_COLORIZE_DIFF_LINE")"
            fi
            printf "\e[47;30m%-30s\e[49;39m \e[1m%1s\e[22m %-63s\n" "${in_lines[$i]}" "$arrow" "$diff_line"
        done
        echo

        exit $diff_ret
    else
        echo "$out"
    fi
done | sed -E ':a; /^\n*$/{ s/\n//; N; ba}'  # Reduce multiple blank lines to single empty line.
