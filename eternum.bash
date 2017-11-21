#!/usr/bin/env bash

ETERNUM_VERSION="0.1.0"

function sgr () {
    printf '\e[%sm' "${1}"
}

function error () {
    printf '%s%s[ERROR]%s %s\n' \
           "$(sgr 31)" "$(sgr 1)" "$(sgr 0)" "${1}" > /dev/stderr
}

function notFound () {
    error "$(sgr 1)${1}$(sgr 0) was not found as a shell builtin or on the PATH"
    error "Ensure that this is running under GNU bash / install that program"
    exit 1
}

{ type "test"   &> /dev/null; } || notFound "test"
{ type "export" &> /dev/null; } || notFound "export"
{ type "mktemp" &> /dev/null; } || notFound "mktemp"
{ type "exit"   &> /dev/null; } || notFound "exit"
{ type "curl"   &> /dev/null; } || notFound "curl"
{ type "gpg2"   &> /dev/null; } || notFound "gpg2"
{ type "jq"     &> /dev/null; } || notFound "jq"
{ type "cat"    &> /dev/null; } || notFound "cat"

if test -z "${XDG_CONFIG_HOME}"; then
    if test -n "${HOME}"; then
        test -d "${HOME}" || {
            error "${HOME} does not exist"
            exit 1
        }
        export XDG_CONFIG_HOME="${HOME}/.config"
    else
        error "Neither XDG_CONFIG_HOME nor HOME is defined"
        exit 2
    fi
fi

test -d "${XDG_CONFIG_HOME}" || {
    error "${XDG_CONFIG_HOME} does not exist"
    exit 3
}

export ETERNUM_HOME="${XDG_CONFIG_HOME}/eternum"

test -d "${ETERNUM_HOME}" || {
    error "${ETERNUM_HOME} does not exist"
    exit 4
}

export ETERNUM_API_KEY_FILE="${ETERNUM_HOME}/api-key.gpg"

test -e "${ETERNUM_API_KEY_FILE}" || {
    error "${ETERNUM_API_KEY_FILE} does not exist"
    error "Please resolve this by running:"
    error "  echo '<api-key>' | gpg2 -ea -r '<email>' > ${ETERNUM_API_KEY_FILE}"
    error "where:"
    error "  <api-key> is the 32-character API key for your Eternum account"
    error "  <email> is the email associated with your PGP public key"
    exit 5
}

test -f "${ETERNUM_API_KEY_FILE}" || {
    error "${ETERNUM_API_KEY_FILE} is not a regular file"
    exit 6
}

test -r "${ETERNUM_API_KEY_FILE}" || {
    error "${ETERNUM_API_KEY_FILE} is not readable"
    exit 7
}

ETERNUM_API_PREFIX="https://www.eternum.io"

function eternumRequest () {
    local ETERNUM_API_KEY TEMPORARY
    ETERNUM_API_KEY="$(gpg2 -d < "${ETERNUM_API_KEY_FILE}" 2>/dev/null)"
    TEMPORARY="$(mktemp -d --tmpdir)"

    {
        printf '{"body":'
        {
            curl -D "${TEMPORARY}/headers" \
                 -H "Authorization: Token ${ETERNUM_API_KEY}" \
                 -s "$@"
        }
        local PROTOCOL HTTPCODE
        PROTOCOL="$(head -n 1 "${TEMPORARY}/headers" | awk '{ print $1 }')"
        HTTPCODE="$(head -n 1 "${TEMPORARY}/headers" | awk '{ print $2 }')"
        printf ',"protocol":"%s"' "${PROTOCOL}"
        printf ',"code":"%s"'     "${HTTPCODE}"
        printf ',"headers":{'
        cat "${TEMPORARY}/headers"                       \
            | tr -d '\r'                                 \
            | tail -n +2                                 \
            | head -n -2                                 \
            | grep -E '^[^:]+: .*$'                      \
            | sed 's/^\([^:]\+\): \(.*\)$/"\1": "\2",/g' \
            | tr -d '\n'                                 \
            | sed 's/,$//g'
        printf '}}'
    } | jq '.'

    { rm -rf "${TEMPORARY}" &>/dev/null; } || true
}

function eternumList () {
    (( $# == 0 )) || {
        error "eternumList: wrong number of arguments"; return 1; }
    eternumRequest -X GET \
                   -H 'Accept: application/json' \
                   "${ETERNUM_API_PREFIX}/api/pin/"
}

function eternumPin () {
    (( $# == 2 )) || {
        error "eternumPin: wrong number of arguments"; return 1; }
    local HASH NAME; HASH="${1}"; NAME="${2}"
    eternumRequest -X POST \
                   -H 'Content-Type: application/json' \
                   -H 'Accept: application/json' \
                   -d "{\"hash\":\"${HASH}\",\"name\":\"${NAME}\"}" \
                   "${ETERNUM_API_PREFIX}/api/pin/"
}

function eternumRename () {
    (( $# == 2 )) || {
        error "eternumRename: wrong number of arguments"
        return 1
    }
    local HASH NAME; HASH="${1}"; NEW_NAME="${2}"
    eternumRequest -X PUT \
                   -H 'Content-Type: application/json' \
                   -H 'Accept: application/json' \
                   -d "{\"name\":\"${NEW_NAME}\"}" \
                   "${ETERNUM_API_PREFIX}/api/pin/${HASH}/"
}

function eternumUnpin () {
    (( $# == 1 )) || {
        error "eternumUnpin: wrong number of arguments"; return 1; }
    local HASH; HASH="${1}"
    eternumRequest -X DELETE \
                   -H 'Accept: application/json' \
                   "${ETERNUM_API_PREFIX}/api/pin/${HASH}/"
}

function eternumStats () {
    (( $# == 1 )) || {
        error "eternumStats: wrong number of arguments"
        return 1
    }
    local HASH; HASH="${1}"
    eternumRequest -X GET \
                   -H 'Accept: application/json' \
                   "${ETERNUM_API_PREFIX}/api/pin/${HASH}/"
}

function eternumHelp () {
    cat > /dev/stderr <<EOF
$(sgr 1)eternum$(sgr 0): the eternum.io command line interface.

Usage:
  $(sgr 1)eternum$(sgr 0) (-h | --help)
  $(sgr 1)eternum$(sgr 0) --version
  $(sgr 1)eternum$(sgr 0) list
  $(sgr 1)eternum$(sgr 0) pin    <hash> <name>
  $(sgr 1)eternum$(sgr 0) rename <hash> <new-name>
  $(sgr 1)eternum$(sgr 0) unpin  <hash>
  $(sgr 1)eternum$(sgr 0) stats  <hash>

Options:
  -h --help    Show this screen.
  --version    Show version.
EOF
}

function eternumVersion () {
    echo "eternum version ${ETERNUM_VERSION}"
}

function eternumInvalid () {
    error "Invalid command: ${1}"
    echo
    eternumHelp
}

if (( $# == 0 )); then
    eternumHelp
else
    COMMAND="${1}"
    shift 1

    case ${COMMAND} in
        "-h")        eternumHelp    "$@" ;;
        "--help")    eternumHelp    "$@" ;;
        "--version") eternumVersion "$@" ;;
        "list")      eternumList    "$@" ;;
        "pin")       eternumList    "$@" ;;
        "rename")    eternumRename  "$@" ;;
        "unpin")     eternumUnpin   "$@" ;;
        "stats")     eternumStats   "$@" ;;
        *)           eternumInvalid "${COMMAND}" ;;
    esac
fi
