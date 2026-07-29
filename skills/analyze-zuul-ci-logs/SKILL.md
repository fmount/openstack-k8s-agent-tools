---
name: analyze-zuul-ci-logs
description: Produce an analysis of observed problems in downloaded Zuul CI logs
argument-hint: "<path>"
user-invocable: true
allowed-tools: ["Bash", "Read", "Grep"]
context: fork
---

# Analyze Zuul CI logs

## General rules

- If something prevents you from taking meaningful steps forward, stop and report the problem to the user.

- Consider the logs read-only. Do not edit anything in them.

- Even if you have tools like `oc` or `ssh` available, don't do direct cluster examination during the analysis. You may be running sandboxed and attempts to connect to the cluster may result in misleading errors. Stick to just analyzing the logs. If you find that it would be helpful to have some more information, which is missing from the report but could be obtained by directly inspecting OpenShift or OpenStack or the underlying servers, highlight that in your analysis.

- You MUST NOT use any command whose purpose is to communicate over network.

- If you have a TODO-like tool available, use it to keep track of steps to do.

- The analysis you produce should include paths to relevant files so that the analysis can be independently verified or continued further from where you left off.

## Zuul CI logs structure hints

- `job-output.txt` or `job-output.txt.gz` is the outermost log file that should be looked at first. If there is an error that failed the job, it should be somewere towards the end of that log file.

- There should be an `openstack-must-gather` directory which should contain various logs from the environment (e.g. from OpenShift pods). Look at the `analyze-must-gather` skill for hints on how to analyze a must-gather report.

- `job-output.txt` can contain very long lines. Using `grep` and `rg` the usual way on the file can often exceed output limits for the agentic tooling, and end up being useless. Instead of normal line-based grepping for failures, use a pattern like `grep -ioE '.{0,100}fatal.{0,500}'` pattern to search for 'fatal' (adjust for other words) with 100 characters of context before and 500 after.

- Often the nested log which is printed on a single line inside `job-output.txt` can be found properly line-delimited in some other place in the logs directory.

- Pay attention to the time in the logs. When you spot the main problem that the job perhaps failed on, it is often useful to cross-reference what was happening at the same time in relevant services and operators.

- Feel free to spawn a subagent to answer a particular question if it seems helpful. Be sure to pass along all important rules and hints to the subagent, and give it a reasonable token budget (e.g. 200 K tokens).

- There can be short transient error states -- this is often ok and expected for convergence-oriented deployment/update processes where many things happen in parallel. If an error happens for a short while and then stops happening (service recovers and progresses further) then it's quite likely it's not a symptom of a problem.

## Analysis workflow

1. Locate `job-output.txt` or `job-output.txt.gz` inside the logs directory and see if there is an error somewere towards the end of that log file. This can give you a good clue for further investigation.

2. Scan the logs for signs of problems with tools like `grep` or `ripgrep`. The words to look for include but may not be limited to "error", "fail", "failure", "fatal", "restart".

3. If the problem scan highlighted obvious problems, read more info to help understand the problem and its cause better (larger file chunks or whole files). Get to the root cause, but even if that doesn't seem possible, gathering more clues is still valuable. (Feel free to use `ls` more than in step 1, in case it seems helpful.)

4. If the previous steps didn't yield any obvious problems, repeat the step "scan the report for signs of problems" but widen the search to words like "warn", "warning". If that yields something, do the step "read more info to help understand the problem".

5. Don't just settle for finding symptoms — find the root causes of the main problems.

6. Output a structured analysis of the observed problems and their causes. Start with the most severe issues first. Don't forget to cite relevant file paths in your analysis.
