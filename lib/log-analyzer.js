#!/usr/bin/env node

/**
 * Advanced Log Analyzer for openstack-k8s-operators Operators
 * Analyzes operator logs using pattern matching and metrics extraction
 */

const fs = require('fs');
const path = require('path');

class openstack-k8s-operatorsLogAnalyzer {
    constructor() {
        this.patterns = this.loadPatterns();
        this.metrics = [];
        this.findings = [];
    }

    // Load pattern definitions
    loadPatterns() {
        try {
            const patternsPath = path.join(__dirname, 'log-patterns.json');
            return JSON.parse(fs.readFileSync(patternsPath, 'utf8'));
        } catch (error) {
            console.error('Error loading patterns:', error.message);
            return { error_patterns: [], warning_patterns: [], success_patterns: [] };
        }
    }

    // Analyze log content
    analyzeLogContent(logContent, options = {}) {
        const lines = logContent.split('\n');
        const analysis = {
            summary: {
                total_lines: lines.length,
                errors: 0,
                warnings: 0,
                successes: 0
            },
            errors: [],
            warnings: [],
            performance: [],
            openstack_issues: [],
            timeline: [],
            recommendations: []
        };

        lines.forEach((line, index) => {
            const lineNumber = index + 1;
            const timestamp = this.extractTimestamp(line);

            // Check error patterns
            this.patterns.error_patterns.forEach(pattern => {
                if (this.matchesPattern(line, pattern.pattern)) {
                    analysis.errors.push({
                        line: lineNumber,
                        timestamp: timestamp,
                        content: line.trim(),
                        pattern: pattern.name,
                        severity: pattern.severity,
                        category: pattern.category,
                        description: pattern.description,
                        suggestions: pattern.suggestions
                    });
                    analysis.summary.errors++;
                }
            });

            // Check warning patterns
            this.patterns.warning_patterns.forEach(pattern => {
                if (this.matchesPattern(line, pattern.pattern)) {
                    analysis.warnings.push({
                        line: lineNumber,
                        timestamp: timestamp,
                        content: line.trim(),
                        pattern: pattern.name,
                        severity: pattern.severity,
                        category: pattern.category,
                        description: pattern.description,
                        suggestions: pattern.suggestions
                    });
                    analysis.summary.warnings++;
                }
            });

            // Check success patterns
            this.patterns.success_patterns.forEach(pattern => {
                if (this.matchesPattern(line, pattern.pattern)) {
                    analysis.summary.successes++;
                }
            });

            // Check performance patterns
            this.patterns.performance_patterns.forEach(pattern => {
                const match = line.match(new RegExp(pattern.pattern, 'i'));
                if (match) {
                    analysis.performance.push({
                        line: lineNumber,
                        timestamp: timestamp,
                        metric: pattern.metric,
                        value: match[1],
                        unit: match[2] || '',
                        content: line.trim()
                    });
                }
            });

            // Check OpenStack specific patterns
            this.patterns.openstack_patterns.forEach(pattern => {
                if (this.matchesPattern(line, pattern.pattern)) {
                    analysis.openstack_issues.push({
                        line: lineNumber,
                        timestamp: timestamp,
                        content: line.trim(),
                        pattern: pattern.name,
                        severity: pattern.severity,
                        category: pattern.category,
                        description: pattern.description,
                        suggestions: pattern.suggestions
                    });
                }
            });
        });

        // Generate recommendations
        analysis.recommendations = this.generateRecommendations(analysis);

        // Generate timeline
        analysis.timeline = this.generateTimeline(analysis);

        return analysis;
    }

    // Check if line matches pattern
    matchesPattern(line, pattern) {
        try {
            return new RegExp(pattern, 'i').test(line);
        } catch (error) {
            console.error(`Invalid regex pattern: ${pattern}`);
            return false;
        }
    }

    // Extract timestamp from log line
    extractTimestamp(line) {
        // Common timestamp patterns
        const patterns = [
            /(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z?)/,  // ISO format
            /(\d{4}\/\d{2}\/\d{2} \d{2}:\d{2}:\d{2})/,              // Simple format
            /(\w{3} \d{1,2} \d{2}:\d{2}:\d{2})/                     // Syslog format
        ];

        for (const pattern of patterns) {
            const match = line.match(pattern);
            if (match) {
                return match[1];
            }
        }

        return null;
    }

    // Generate recommendations based on findings
    generateRecommendations(analysis) {
        const recommendations = [];

        // High severity errors
        const criticalErrors = analysis.errors.filter(e => e.severity === 'critical');
        if (criticalErrors.length > 0) {
            recommendations.push({
                priority: 'critical',
                title: 'Critical Errors Detected',
                description: `Found ${criticalErrors.length} critical errors that require immediate attention`,
                actions: [
                    'Stop operator if running',
                    'Review panic traces and stack dumps',
                    'Check for resource limits and constraints',
                    'Verify code logic and error handling'
                ]
            });
        }

        // RBAC issues
        const rbacErrors = analysis.errors.filter(e => e.category === 'permissions');
        if (rbacErrors.length > 3) {
            recommendations.push({
                priority: 'high',
                title: 'RBAC Permission Issues',
                description: `Multiple permission errors detected (${rbacErrors.length} instances)`,
                actions: [
                    'Review ClusterRole and RoleBinding configurations',
                    'Verify ServiceAccount has required permissions',
                    'Check namespace-specific permissions'
                ]
            });
        }

        // Performance issues
        const perfIssues = analysis.performance.filter(p =>
            (p.metric === 'duration' && parseFloat(p.value) > 30) ||
            (p.metric === 'queue_depth' && parseInt(p.value) > 100)
        );
        if (perfIssues.length > 0) {
            recommendations.push({
                priority: 'medium',
                title: 'Performance Concerns',
                description: 'Slow reconciliation or large queue depths detected',
                actions: [
                    'Profile reconciliation logic',
                    'Consider increasing worker count',
                    'Review external API call patterns',
                    'Implement caching where appropriate'
                ]
            });
        }

        // OpenStack specific issues
        if (analysis.openstack_issues.length > 0) {
            recommendations.push({
                priority: 'high',
                title: 'OpenStack Service Issues',
                description: `Detected ${analysis.openstack_issues.length} OpenStack service-related problems`,
                actions: [
                    'Check OpenStack service health',
                    'Verify service credentials and endpoints',
                    'Review network connectivity to OpenStack APIs'
                ]
            });
        }

        return recommendations;
    }

    // Generate timeline of significant events
    generateTimeline(analysis) {
        const events = [];

        // Add all errors with timestamps
        analysis.errors.forEach(error => {
            if (error.timestamp) {
                events.push({
                    timestamp: error.timestamp,
                    type: 'error',
                    severity: error.severity,
                    event: error.pattern,
                    line: error.line
                });
            }
        });

        // Add performance events
        analysis.performance.forEach(perf => {
            if (perf.timestamp && perf.metric === 'duration' && parseFloat(perf.value) > 10) {
                events.push({
                    timestamp: perf.timestamp,
                    type: 'performance',
                    severity: 'medium',
                    event: `Slow reconciliation (${perf.value}${perf.unit})`,
                    line: perf.line
                });
            }
        });

        // Sort by timestamp (rough sorting, may need improvement for different formats)
        return events.sort((a, b) => {
            if (a.timestamp < b.timestamp) return -1;
            if (a.timestamp > b.timestamp) return 1;
            return a.line - b.line;
        });
    }

    // Format analysis results for display
    formatResults(analysis, options = {}) {
        const { format = 'text', verbose = false } = options;

        if (format === 'json') {
            return JSON.stringify(analysis, null, 2);
        }

        let output = '';

        // Summary
        output += '📊 Log Analysis Summary\n';
        output += '='.repeat(25) + '\n';
        output += `Total Lines: ${analysis.summary.total_lines}\n`;
        output += `Errors: ${analysis.summary.errors}\n`;
        output += `Warnings: ${analysis.summary.warnings}\n`;
        output += `Successes: ${analysis.summary.successes}\n\n`;

        // Critical findings
        if (analysis.errors.length > 0) {
            output += '🚨 Critical Issues\n';
            output += '-'.repeat(20) + '\n';
            analysis.errors.slice(0, verbose ? -1 : 5).forEach(error => {
                output += `[${error.severity.toUpperCase()}] Line ${error.line}: ${error.pattern}\n`;
                output += `  ${error.description}\n`;
                if (verbose) {
                    output += `  Content: ${error.content}\n`;
                    output += `  Suggestions: ${error.suggestions.join(', ')}\n`;
                }
                output += '\n';
            });
        }

        // Recommendations
        if (analysis.recommendations.length > 0) {
            output += '💡 Recommendations\n';
            output += '-'.repeat(20) + '\n';
            analysis.recommendations.forEach(rec => {
                output += `[${rec.priority.toUpperCase()}] ${rec.title}\n`;
                output += `  ${rec.description}\n`;
                output += `  Actions: ${rec.actions.join('; ')}\n\n`;
            });
        }

        // Performance insights
        if (analysis.performance.length > 0) {
            output += '⚡ Performance Metrics\n';
            output += '-'.repeat(25) + '\n';
            const durationsMetrics = analysis.performance.filter(p => p.metric === 'duration');
            if (durationsMetrics.length > 0) {
                const durations = durationsMetrics.map(p => parseFloat(p.value));
                const avgDuration = durations.reduce((a, b) => a + b, 0) / durations.length;
                output += `Average reconciliation time: ${avgDuration.toFixed(2)}s\n`;
                output += `Max reconciliation time: ${Math.max(...durations)}s\n`;
            }
        }

        return output;
    }

    // CLI interface
    static runCLI() {
        const args = process.argv.slice(2);

        if (args.includes('--help') || args.includes('-h')) {
            console.log('Usage: log-analyzer.js [options] <log-file>');
            console.log('Options:');
            console.log('  --json           Output in JSON format');
            console.log('  --verbose        Show detailed information');
            console.log('  --patterns       Show available patterns');
            console.log('  --help           Show this help');
            return;
        }

        const analyzer = new openstack-k8s-operatorsLogAnalyzer();

        if (args.includes('--patterns')) {
            console.log('Available patterns:');
            console.log('Error patterns:', analyzer.patterns.error_patterns.map(p => p.name));
            console.log('Warning patterns:', analyzer.patterns.warning_patterns.map(p => p.name));
            console.log('Performance patterns:', analyzer.patterns.performance_patterns.map(p => p.name));
            return;
        }

        const logFile = args.find(arg => !arg.startsWith('--'));
        if (!logFile) {
            console.error('Please provide a log file to analyze (use - for stdin)');
            process.exit(1);
        }

        const formatOptions = {
            format: args.includes('--json') ? 'json' : 'text',
            verbose: args.includes('--verbose')
        };

        try {
            let logContent;
            if (logFile === '-') {
                logContent = fs.readFileSync('/dev/stdin', 'utf8');
            } else {
                logContent = fs.readFileSync(logFile, 'utf8');
            }
            const analysis = analyzer.analyzeLogContent(logContent);
            console.log(analyzer.formatResults(analysis, formatOptions));
        } catch (error) {
            console.error('Error analyzing log file:', error.message);
            process.exit(1);
        }
    }
}

// CLI execution
if (require.main === module) {
    openstack-k8s-operatorsLogAnalyzer.runCLI();
}

module.exports = openstack-k8s-operatorsLogAnalyzer;
