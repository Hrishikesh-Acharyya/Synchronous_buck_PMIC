#
# Filename:         help.awk
#
# File Description: Prints the `make help` screen from the Makefile and the mk
#                   files, in the order make includes them:
#                     ##@ Heading               starts a group
#                     target: deps  ## text     lists a target under it
#                     ##- name  text            lists a generated target family
#                   Per-module families are generated inside a define and have
#                   no rule line of their own, hence the ##- form.
#
#                   Usage: awk -v c_hd=... -v c_tg=... -v c_off=... -f help.awk <files>
#
# Global variables: c_hd, c_tg, c_off - colour escapes (empty for plain text)

BEGIN { printf "Usage: make %s<target>%s [VAR=value ...]\n", c_tg, c_off }

/^##@ / {
    sub(/^##@ /, "")
    printf "\n%s%s%s\n", c_hd, $0, c_off
    next
}

/^##- / {
    line = $0
    sub(/^##- /, "", line)
    name = line
    sub(/ .*/, "", name)
    sub(/^[^ ]+ +/, "", line)
    printf "  %s%-16s%s %s\n", c_tg, name, c_off, line
    next
}

/^[a-zA-Z_][a-zA-Z0-9_-]*:.*## / {
    target = $0
    sub(/:.*/, "", target)
    text = $0
    sub(/^[^#]*## /, "", text)
    printf "  %s%-16s%s %s\n", c_tg, target, c_off, text
}
