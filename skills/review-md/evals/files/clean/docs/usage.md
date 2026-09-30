# Using tally

## Synopsis

```text
tally.sh [-i] WORD FILE...
```

`tally.sh` reads each FILE and counts the lines that contain WORD. WORD is matched as a fixed
string, not as a regular expression.

## Options

- `-i`: ignore case when matching WORD. It must come before WORD.

## Output

For each FILE, `tally.sh` prints the count, a tab, and the file name, in the order the files were
given. A last line prints the sum of the counts, a tab, and the word `total`:

```text
3	app.log
0	worker.log
3	total
```

## Exit status

- 0: every FILE was read.
- 1: a FILE could not be read. The counts printed before it stay on standard output, and no total
  is printed.
- 2: WORD or FILE is missing.

## Example

To count the lines that mention `timeout` in the logs under /var/log/app/, ignoring case:

```sh
tally.sh -i timeout /var/log/app/*.log
```
