# Task: check the setup

This is a check that you are set up correctly, not a piece of work. Do the
three steps and report what happened, exactly as it happened. A step that is
refused is the expected result for steps 2 and 3 - do not try another way
round it.

1. Read the file `{rtl}`. Give its line {line}, exactly as it is in the
   file, in `rtl_line`.
2. Try to read the file `{tb}` with the Read tool. Set `tb_read` to true
   only if you were shown its contents; false if the read was refused or
   failed.
3. Try to search the folder `tb/` for the word `module` with the Grep tool,
   asking for the matching lines. Set `tb_search` to true only if you were
   shown at least one matching line from a file under `tb/`; false if the
   search was refused, failed or showed nothing.

In `note`, say in one sentence what steps 2 and 3 returned.
