---
name: analyze-logs
description: Advanced log analysis for openstack-k8s-operators operators with pattern matching and intelligent insights
user-invocable: true
allowed-tools: ["Bash", "Read", "Grep"]
context: fork
---

# Analyze Logs

This skill provides advanced log analysis for openstack-k8s-operators operators using intelligent pattern matching, metrics extraction, and actionable recommendations.

## Automated Analysis Features

When analyzing logs, I will:

1. **Pattern Recognition**: Identify 25+ predefined error and warning patterns
2. **Performance Metrics**: Extract reconciliation times, queue depths, API latencies
3. **Timeline Generation**: Create chronological event sequences
4. **Root Cause Analysis**: Correlate related issues and suggest fixes
5. **OpenStack Integration**: Detect service-specific issues (Nova, Keystone, etc.)

## Advanced Pattern Library

The skill includes comprehensive patterns for:

### Error Detection

- **API Connectivity**: Connection refused, dial failures
- **RBAC Issues**: Permission denied, forbidden access
- **Resource Problems**: Not found, validation failures
- **Runtime Errors**: Panics, nil pointer exceptions
- **Image Issues**: Pull failures, registry access
- **Webhook Failures**: Admission controller errors

### Performance Analysis

- **Slow Reconciliation**: >30s reconciliation times
- **Queue Issues**: Large queue depths (>100 items)
- **API Latency**: Slow Kubernetes API responses
- **Resource Conflicts**: Optimistic locking failures

### OpenStack Specific

- **Openstack Service**: Openstack service failures (Glance, Nova, Cinder, Manila)
- **Keystone Auth**: Authentication/authorization issues
- **Database**: Connection and SQL errors
- **Network**: Neutron service problems

## Log Analyzer Tool

Includes specialized analyzer (`log-analyzer.js`) that:

```bash
# Analyze log file with detailed output
node ./lib/log-analyzer.js --verbose operator.log

# JSON output for integration
node ./lib/log-analyzer.js --json operator.log

# Show available patterns
node ./lib/log-analyzer.js --patterns
```

## Analysis Output

### Summary Report

- Total log lines processed
- Error/warning/success counts
- Critical issue identification
- Performance metric extraction

### Detailed Findings

- Line-by-line issue mapping
- Severity classification (critical/high/medium/low)
- Category grouping (permissions/connectivity/performance)
- Specific remediation suggestions

### Timeline View

- Chronological event sequence
- Error clustering analysis
- Performance degradation tracking
- Service health transitions

### Recommendations

- **Critical**: Immediate action required (panics, crashes)
- **High**: Service impacting (RBAC, connectivity)
- **Medium**: Performance concerns (slow reconciliation)
- **Low**: Minor issues (occasional conflicts)

## Usage Patterns

### 1. **Real-time Log Analysis**

```bash
# Stream and analyze live logs
kubectl logs -f deployment/operator-name | node log-analyzer.js -
```

### 2. **Historical Analysis**

```bash
# Analyze collected logs
kubectl logs deployment/operator-name --since=1h > operator.log
node log-analyzer.js --verbose operator.log
```

### 3. **Multi-Pod Analysis**

```bash
# Analyze logs from all operator pods
kubectl logs -l app=operator --all-containers=true > combined.log
node log-analyzer.js combined.log
```

### 4. **Pattern-Specific Search**

```bash
# Focus on specific issue types
grep -E "(error|panic|failed)" operator.log | node log-analyzer.js -
```

## Integration Points

- **TodoWrite**: Create action items from analysis
- **Debug-Operator**: Use findings to guide debugging
- **Explain-Flow**: Correlate errors with code paths
- **Plan-Feature**: Identify improvement opportunities

## Intelligent Insights

The skill provides:

- **Correlation Analysis**: Link related errors across time
- **Trend Detection**: Identify recurring patterns
- **Performance Baselines**: Compare against normal behavior
- **Impact Assessment**: Prioritize fixes by severity and frequency

Simply invoke `/analyze-logs` with a log file path or kubectl command, and receive comprehensive analysis with actionable recommendations.
