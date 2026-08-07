This projet uses `shellcheck` with almost all rules enabled. I set it up this way because I'm new to shell scripting and want to be alerted of unsafe patterns, but this strict setup can cause safe code to be flagged. I want to maintain a delicate balance between keeping rules that can improve code quality, and turning off rules that aren't necessary.

If you truly believe a rule is wholly unnecessary, you can update .shellcheckrc. Otherwise, I recommend modifying the code to fix the line error or adding an inline "ignore" directive.
