[`bash_strace()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L10)
---------------

Trace files opened by an interactive Bash startup.


[`prompt_venv_prefix()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L16)
----------------------

Print the current Python virtualenv prompt prefix from PS1.


[`prompt_dname()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L28)
----------------

colors Set PS1 to show only the current directory name in blue.


[`prompt_dfull()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L30)
----------------

Set PS1 to show the full current path in blue.


[`prompt_short()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L32)
----------------

Set PS1 to show user, short host, and current directory name.


[`prompt_med()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L34)
--------------

Set PS1 to show user, short host, and full current path.


[`prompt_long()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L36)
---------------

Set PS1 to show user, fully-qualified host, and full current path.


[`prompt_reset()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L38)
----------------

Reset PS1 to the default colored shell-utils prompt.


[`ccmd()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L41)
--------

Read, save, and evaluate one interactive command line.


[`color()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L52)
---------

Run a command while coloring its stderr stream red.

* $@ - Command and arguments to execute.


[`line2space()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L60)
--------------

Convert newline-separated text to a single space-separated line.

Takes input from stdin when piped, otherwise from the first argument.


[`space2line()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L71)
--------------

Convert spaces in stdin to newlines.


[`line2csstring()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L74)
-----------------

Convert whitespace-separated stdin tokens to single-quoted CSV values.


[`line2csstring_alt()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L81)
---------------------

Convert newline-separated stdin tokens to single-quoted CSV values.


[`string_replace()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L103)
------------------

Replace all instances of a string with another string.

Takes a piped in string (any number of lines) and outputs the the same string with all instances of a specified string replaced with another provided string. This is a simple wrapper of the `sed` command.

* $1 - First string, to be searched for and replaced.
* $2 - Second string, to replace the first string with.

Examples

    echo "dog cat dog cat" | string_replace 'cat' 'pig'
    => "dog pig dog pig"

Prints to stdout the string with replacements made.

Returns the exit code of the wrapped `sed` command.


[`string_prepend()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L122)
------------------

Prepend a string to the beginning of each input line.

Takes a piped in string (any number of lines) and outputs the the same string with the provided string affixed to the beginning of each input line. This is a simple wrapper of the `sed` command.

* $1 - The string to be prepended to each input line.

Examples

    echo "world" | string_prepend "hello "
    => "hello world"

Prints to stdout the string with prepends added.

Returns the exit code of the wrapped `sed` command.


[`string_append()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L141)
-----------------

Append a string to the end of each input line.

Takes a piped in string (any number of lines) and outputs the the same string with the provided string affixed to the end of each input line. This is a simple wrapper of the `sed` command.

* $1 - The string to be appended to each input line.

Examples

    echo "hello" | string_append " world"
    => "hello world"

Prints to stdout the string with appends added.

Returns the exit code of the wrapped `sed` command.


[`echoeval()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L168)
------------

Run `eval echo` on the provided arguments.

Takes in a string of arguments, provided either as function arguments or piped in on a single line, and runs  them through `eval "echo <arguments>"` so that globs can be expanded.

* $@ - Arguments provided to `echo` command.

Examples

    ls *.txt
    ./test1.txt  ./test2.txt  ./test3.txt

    echoeval "*.txt"
    => test1.txt test2.txt test3.txt

    echo "*.txt" | echoeval
    => test1.txt test2.txt test3.txt

Prints to stdout the result of the `echo` command`.

Returns the exit code of the `echo` command.


[`tokentx()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L184)
-----------

Apply a token replacement template to each token from stdin.

Takes tokens from stdin. If stdin contains one line, tokens are split on spaces; otherwise each line is treated as one token.

* $1 - Template string where each `%` is replaced with the current token.


[`layz()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L210)
--------

Expand numbered placeholders in a command and execute it.

`%0`, `%1`, and later placeholders are replaced with the corresponding command arguments. Use `-debug`, `-dryrun`, `-db`, or `-dr` to print the expanded command instead of executing it.


[`timestmap2datestr()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L246)
---------------------

Convert compact timestamps to `YYYY-MM-DD HH:MM:SS` strings.


[`link_or_copy()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L267)
----------------

Link file(s) if possible, otherwise copy.

First executes `ln -f <arguments>` with all provided arguments appended If the return code of that command is non-zero, executes `cp <arguments>` using the same set of provided arguments.

* $@ - Arguments provided to `ln -f` or `cp` to perform link or copy.

Examples

    link_or_copy "src_file.txt" "dst_file.txt"

Returns the non-zero exit code of `cp` command if both `ln -f` and `cp` are unsuccessful (non-zero exit code), or 0 otherwise.


[`conda_activate()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L274)
------------------

Activate a Conda environment named after the current directory.


[`pixi_create()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L282)
---------------

Create a `.pixi` symlink to a shared Pixi environment directory.

* $1 - Environment name. Defaults to the basename of the current directory.


[`pixi_remove()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L306)
---------------

Remove the shared Pixi environment and local `.pixi` symlink.

* $1 - Environment name. Defaults to the basename of the current directory.


[`absymlink_defunct()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L331)
---------------------

Create symlinks using absolute target paths.

Non-option arguments are resolved with `readlink -f` before passing them to `ln -s`.


[`mv_and_absymlink()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L349)
--------------------

Move files or directories and leave absolute symlinks in their place.

Accepts normal `mv`-style source and destination arguments. Use `-dryrun`, `-debug`, `-dr`, or `-db` to print the move and symlink commands.


[`touch_all()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L413)
-------------

Recursively touch all files under one or more directories.

* $@ - Directories whose contained files should be touched.


[`trashem()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L431)
-----------

Move paths to trash and save removal metadata next to each path.

Uses `trash-put` from `trash-cli`. Arguments before the first option are treated as paths; remaining arguments are passed to `find`.


[`headtail()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L463)
------------

Print the first and last N lines from stdin.

* $1 - Number of lines to print from the head and tail.


[`get_csv_cols()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L468)
----------------

Placeholder for CSV column extraction.


[`wread()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L473)
---------

Read a line with `IFS` cleared.


[`wread0()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L477)
----------

Read a NUL-delimited value with `IFS` cleared.


[`read_csv()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L511)
------------

Read CSV file field values line by line.

This method is a substitute for the standard `read` command used to more easily parse one or more field values from a CSV file. In each call to `read_csv`, variables are set in the current shell to reflect the values of the indicated field names at the last line read by an internal call to the `read` command on the CSV file. The names of these variables are the same as the field names, and are meant to be used directly. The (non-local) variables containing the CSV field values are created and modified through `eval`. Once the final line in the CSV file has been read, the variables are unset through `eval "unset <field_name>"`.

* $1 - Comma-separated list of field names whose values will be read.

Examples

    line_num=0
    while read_csv field1,field2; do
        ((line_num++))
        echo "line ${line_num}: field1=${field1}, field2=${field2}"
    done < "./example.csv"
    => "line 1: field1=some_value1, field2=other_value1"
    => "line 2: field1=some_value2, field2=other_value2"
    => ...

Returns the exit code of the `read` command used to parse the last line read from the CSV file.


[`csv_line`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L558)
----------

No 'get fields' match strings in first row of CSV, so assume the CSV has no header and match order of 'get fields' to the order of CSV columns.


[`read_status`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L573)
-------------

This is likely the case where we're reading the last line of input and it doesn't have a trailing newline so 'read' has a nonzero exit status. We still want to parse this line.


[`stat_sec()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L615)
------------

Print file modification times as Unix epoch seconds.

* $@ - Paths passed to `stat`.


[`du_k()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L620)
--------

Print disk usage in 1K blocks.


[`du_m()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L622)
--------

Print disk usage in 1M blocks.


[`du_g()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L624)
--------

Print disk usage in 1G blocks.


[`du_t()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L626)
--------

Print disk usage in 1T blocks.


[`uniq_preserve_order()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L629)
-----------------------

Remove duplicate stdin lines while preserving first-seen order.


[`smart_sort()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L641)
--------------

Sort lines by a formatted numeric substring.

* $1 - Extended regex with a capture group for the sort key.
* $2 - `printf` format used to zero-pad or otherwise normalize the sort key.

Examples

    ls *_meta.txt | smart_sort '_seg([0-9]+)_' '_seg%04d_'


[`wc_nlines()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L654)
-------------

Count lines in each input item.

* $@ - Items passed through `process_items`.


[`count_items()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L659)
---------------

Count repeated stdin items and print counts sorted by item.


[`count_by_date()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L664)
-----------------

Count month-day occurrences found in stdin.


[`count_by_month()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L668)
------------------

Count month occurrences found in stdin.


[`count_by_date_with_ex()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L672)
-------------------------

Count month-day occurrences and include one matching example line.


[`count_by_month_with_ex()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L676)
--------------------------

Count month occurrences and include one matching example line.


[`strip_cols()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L684)
--------------

Normalize column delimiters in stdin.

* $1 - Input column delimiter. Defaults to a space.
* $2 - Output column delimiter. Defaults to a space.


[`get_cols()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L710)
------------

Print selected columns from stdin.

Numeric arguments select columns. The first non-numeric argument sets the input delimiter, and the second sets the output delimiter.


[`sum_cols()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L766)
------------

Sum each column from delimited numeric stdin.

* $1 - Column delimiter. Defaults to a space.


[`sum_all()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L792)
-----------

Sum all numeric fields from delimited stdin.

* $1 - Column delimiter. Defaults to a space.


[`get_stats()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L809)
-------------

Print count, sum, min, max, median, average, standard deviation, range, and interval for stdin numbers.


[`get_intervals()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L827)
-----------------

Print differences between consecutive numeric stdin values.


[`filesize_diff_perc()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L836)
----------------------

Compare matching file sizes between two directory trees.

* $1 - Base directory.
* $2 - Comparison directory.
* $@ - Additional `find` arguments after the first two paths.


[`find_alias()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L856)
--------------

Dispatch shared parsing and execution for shell-utils find wrappers.

* $1 - Wrapper name controlling default depth and output behavior.
* $@ - Arguments passed through to `find` after wrapper-specific parsing.


[`findup()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L979)
----------

Search upward from paths using `find` at each ancestor directory.


[`findl()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L983)
---------

Run `find` at depth one by default.


[`findls()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L987)
----------

Run `find -ls` at depth one by default with trimmed listing output.


[`findlsh()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L991)
-----------

Run a human-readable `ls -lh` for files found at depth one by default.


[`findst()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L995)
----------

Run `findls` for the starting path itself.


[`findd1()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L999)
----------

Find directories at depth one by default.


[`find_missing_suffix()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1010)
-----------------------

Find files whose sibling files with related suffixes are missing.

* $1 - Directory to search.
* $2 - Base suffix used to identify candidate files.
* $@ - Suffixes to check, followed by optional `find` arguments.

Use `-any` to require any checked suffix, `-all` to require all checked suffixes, and `-inverse` to invert the match.


[`ls_suffix()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1089)
-------------

List suffixes under paths beginning with a prefix.

* $1 - Path prefix to strip from matching entries.


[`apt_cleanup()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1097)
---------------

Update apt metadata and remove cached or unused packages.


[`conda_history()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1102)
-----------------

Export the active Conda environment from explicit history.


[`pip_history()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1107)
---------------

List installed Python packages with verbose metadata.


[`git_remote()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1115)
--------------

Print the current repository origin URL.


[`git_webpage()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1120)
---------------

Open the current repository origin URL in Google Chrome.


[`git_drop_all_changes()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1139)
------------------------

Drop all unstaged and staged working tree changes.


[`git_reset_keep_changes()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1144)
--------------------------

Reset HEAD back one commit while keeping working tree changes.


[`git_reset_drop_changes()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1149)
--------------------------

Hard-reset the current repository to HEAD.


[`git_stash_apply_no_merge()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1154)
----------------------------

Apply the stash tree directly without Git's merge machinery.


[`git_apply_force()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1160)
-------------------

Apply a patch with rejects and whitespace fixes.


[`git_remove_local_branches()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1165)
-----------------------------

Delete all local branches except the current branch.


[`git_branch_cleanup()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1169)
----------------------

Fetch pruned refs and delete local branches whose upstream is gone.


[`git_make_exec()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1175)
-----------------

Mark files executable in Git index and filesystem.


[`git_remove_exec()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1185)
-------------------

Mark files non-executable in Git index and filesystem.


[`git_zip()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1195)
-----------

Create a zip archive of the current repository HEAD.


[`git_cmd_in()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1211)
--------------

Run one or more Git commands across repository directories.

* $1 - Command group name used in usage output.
* $@ - Git command names, options, and repository directories.


[`git_branch_in()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1331)
-----------------

Run `git branch` across repository directories.


[`git_status_in()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1335)
-----------------

Run `git status` across repository directories.


[`git_fetch_in()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1339)
----------------

Run `git fetch` across repository directories.


[`git_pull_in()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1346)
---------------

Run `git pull` across repository directories.

Use `-stash` to run `git stash`, `git pull`, and `git stash apply` in each repository.


[`git_zip_in()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1377)
--------------

Create Git HEAD zip archives across repository directories.


[`git_clone_replace()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1384)
---------------------

Clone a repository and replace an existing same-named local directory.

* $1 - Git repository URL.


[`qstat_info()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1430)
--------------

Print PBS `qstat` job information, optionally filtered.

Options include `-user USER`, `-state STATE`, `-logs`, `-home`, and `-dryrun`.


[`qstat_r_jobs()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1496)
----------------

Print running PBS job IDs and names for the current user.


[`qstat_r_joblogs()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1500)
-------------------

Print running PBS job log paths for the current user.


[`qstat_r_joblogs_home()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1504)
------------------------

Print running PBS job log paths rewritten under `$HOME`.


[`ssh_alias()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1509)
-------------

SSH to a host using `~/.bashrc_from_ssh` as the remote Bash rcfile.


[`ssh_expect_passphrase()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1517)
-------------------------

Run SSH through `expect` and provide a key passphrase.

* $1 - SSH key passphrase.
* $@ - SSH arguments after the passphrase.


[`rsync_alias()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1529)
---------------

Build and run an rsync command with automatic remote direction support.

* $1 - Direction: `to-remote`, `from-remote`, or `auto`.
* $2 - Remote host.
* $@ - Optional rsync arguments, then source and destination paths.


[`rsync_alias_defopt()`](https://github.com/ehusby/shell-utils/blob/main/linux/lib/bash_shell_func.sh#L1598)
----------------------

Run `rsync_alias auto` with default recursive transfer options.

* $1 - Remote host.
* $@ - Source and destination paths, plus any trailing arguments accepted by `rsync_alias`.


