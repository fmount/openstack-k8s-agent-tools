#!/usr/bin/env node

/**
 * Go Code Style Analyzer for openstack-k8s-operators Operators
 * Analyzes and suggests improvements based on openstack-k8s-operators conventions
 */

const fs = require('fs');
const path = require('path');

class GoStyleAnalyzer {
    constructor() {
        this.issues = [];
        this.suggestions = [];
        this.modernizations = [];
    }

    // Analyze Go file for style issues
    analyzeFile(filePath) {
        if (!fs.existsSync(filePath)) {
            console.error(`File not found: ${filePath}`);
            return null;
        }

        const content = fs.readFileSync(filePath, 'utf8');
        const analysis = {
            file: filePath,
            issues: [],
            suggestions: [],
            modernizations: [],
            stats: {
                lines: content.split('\n').length,
                functions: 0,
                types: 0
            }
        };

        this.analyzeContent(content, analysis);
        return analysis;
    }

    // Main content analysis
    analyzeContent(content, analysis) {
        const lines = content.split('\n');

        lines.forEach((line, index) => {
            const lineNum = index + 1;

            // Check for various style issues
            this.checkSliceDeclaration(line, lineNum, analysis);
            this.checkMapDeclaration(line, lineNum, analysis);
            this.checkStringConcatenation(line, lineNum, analysis);
            this.checkErrorHandling(line, lineNum, analysis);
            this.checkLogging(line, lineNum, analysis);
            this.checkNaming(line, lineNum, analysis);
            this.checkImports(line, lineNum, analysis);
            this.checkControllerPatterns(line, lineNum, analysis);
        });

        // Overall file analysis
        this.analyzeFileStructure(content, analysis);
    }

    // Check for old-style slice declarations
    checkSliceDeclaration(line, lineNum, analysis) {
        // Pattern: var items []Type = []Type{}
        const oldSlicePattern = /var\s+\w+\s+\[\]\w+\s*=\s*\[\]\w+\{\}/;
        if (oldSlicePattern.test(line)) {
            analysis.modernizations.push({
                line: lineNum,
                type: 'slice_declaration',
                current: line.trim(),
                suggestion: line.replace(/\s*=\s*\[\]\w+\{\}/, ''),
                description: 'Use zero-value initialization for slices'
            });
        }
    }

    // Check for old-style map declarations
    checkMapDeclaration(line, lineNum, analysis) {
        // Pattern: var m map[K]V = make(map[K]V)
        const oldMapPattern = /var\s+\w+\s+map\[[^\]]+\]\w+\s*=\s*make\(map\[[^\]]+\]\w+\)/;
        if (oldMapPattern.test(line)) {
            analysis.modernizations.push({
                line: lineNum,
                type: 'map_declaration',
                current: line.trim(),
                suggestion: line.replace(/var\s+(\w+)\s+(map\[[^\]]+\]\w+)\s*=\s*make\(\2\)/, 'var $1 = make($2)'),
                description: 'Use short variable declaration for maps'
            });
        }
    }

    // Check for inefficient string concatenation
    checkStringConcatenation(line, lineNum, analysis) {
        // Look for string concatenation in loops
        if (line.includes('+=') && line.includes('"')) {
            analysis.suggestions.push({
                line: lineNum,
                type: 'string_concatenation',
                current: line.trim(),
                description: 'Consider using strings.Builder for efficient string concatenation',
                severity: 'medium'
            });
        }
    }

    // Check error handling patterns
    checkErrorHandling(line, lineNum, analysis) {
        // Look for naked error returns
        if (line.includes('return') && line.includes('err') && !line.includes('fmt.Errorf')) {
            analysis.suggestions.push({
                line: lineNum,
                type: 'error_handling',
                current: line.trim(),
                description: 'Consider wrapping errors with context using fmt.Errorf',
                severity: 'medium'
            });
        }

        // Check for proper controller-runtime error patterns
        if (line.includes('errors.IsNotFound') && !line.includes('ctrl.Result{}')) {
            analysis.suggestions.push({
                line: lineNum,
                type: 'controller_error_pattern',
                current: line.trim(),
                description: 'Use ctrl.Result{} for NotFound errors in reconcilers',
                severity: 'low'
            });
        }
    }

    // Check logging patterns
    checkLogging(line, lineNum, analysis) {
        // Look for fmt.Printf/Println instead of proper logging
        if (line.match(/fmt\.(Printf|Println|Print)\(/)) {
            analysis.issues.push({
                line: lineNum,
                type: 'logging',
                current: line.trim(),
                description: 'Use structured logging (ctrl.LoggerFrom(ctx)) instead of fmt.Print',
                severity: 'medium'
            });
        }

        // Check for proper logger context
        if (line.includes('.Info(') && !line.includes('WithValues')) {
            const hasContext = line.includes('log := ctrl.LoggerFrom(ctx)');
            if (!hasContext) {
                analysis.suggestions.push({
                    line: lineNum,
                    type: 'logging_context',
                    current: line.trim(),
                    description: 'Consider adding context values to logger',
                    severity: 'low'
                });
            }
        }
    }

    // Check naming conventions
    checkNaming(line, lineNum, analysis) {
        // Check for exported functions/types without documentation
        if (line.match(/^func\s+[A-Z]\w*/) || line.match(/^type\s+[A-Z]\w*\s+struct/)) {
            analysis.suggestions.push({
                line: lineNum,
                type: 'documentation',
                current: line.trim(),
                description: 'Exported functions and types should have documentation comments',
                severity: 'low'
            });
        }

        // Check receiver naming
        const receiverPattern = /func\s*\(\s*(\w+)\s+\*?(\w+)\s*\)/;
        const match = line.match(receiverPattern);
        if (match) {
            const receiverName = match[1];
            const typeName = match[2];
            const expectedName = typeName.charAt(0).toLowerCase();

            if (receiverName !== expectedName && receiverName.length > 2) {
                analysis.suggestions.push({
                    line: lineNum,
                    type: 'receiver_naming',
                    current: line.trim(),
                    description: `Consider using '${expectedName}' instead of '${receiverName}' for receiver`,
                    severity: 'low'
                });
            }
        }
    }

    // Check import organization
    checkImports(line, lineNum, analysis) {
        if (line.trim().startsWith('import ')) {
            // This would need more sophisticated logic to check import grouping
            // For now, just suggest running goimports
            analysis.suggestions.push({
                line: lineNum,
                type: 'imports',
                description: 'Run goimports to organize imports properly',
                severity: 'low'
            });
        }
    }

    // Check controller-runtime specific patterns
    checkControllerPatterns(line, lineNum, analysis) {
        // Check for proper context usage in Reconcile method signature
        const reconcileSignature = line.match(/func\s*\(\w+\s+\*?\w+\)\s+Reconcile\s*\(/);
        if (reconcileSignature && !line.includes('ctx context.Context')) {
            analysis.issues.push({
                line: lineNum,
                type: 'controller_context',
                current: line.trim(),
                description: 'Reconcile functions should accept context.Context as first parameter',
                severity: 'high'
            });
        }

        // Check for finalizer patterns
        if (line.includes('finalizer') && !line.includes('controllerutil')) {
            analysis.suggestions.push({
                line: lineNum,
                type: 'finalizer_pattern',
                current: line.trim(),
                description: 'Use controllerutil.AddFinalizer/RemoveFinalizer for proper finalizer handling',
                severity: 'medium'
            });
        }
    }

    // Analyze overall file structure
    analyzeFileStructure(content, analysis) {
        // Count functions and types
        analysis.stats.functions = (content.match(/func\s+/g) || []).length;
        analysis.stats.types = (content.match(/type\s+\w+\s+struct/g) || []).length;

        // Check for missing package documentation
        if (!content.match(/^\/\/ Package \w+/)) {
            analysis.suggestions.push({
                line: 1,
                type: 'package_documentation',
                description: 'Consider adding package documentation',
                severity: 'low'
            });
        }

        // Check for proper imports grouping
        const imports = content.match(/import\s*\(\s*([\s\S]*?)\s*\)/);
        if (imports) {
            const importLines = imports[1].split('\n').filter(line => line.trim());
            if (importLines.length > 3) {
                analysis.suggestions.push({
                    line: 0,
                    type: 'import_grouping',
                    description: 'Consider grouping imports: standard, third-party, local',
                    severity: 'low'
                });
            }
        }
    }

    // Generate style report
    generateReport(analysis) {
        if (!analysis) return '';

        let report = `📊 Style Analysis Report for ${path.basename(analysis.file)}\n`;
        report += '='.repeat(50) + '\n\n';

        // Statistics
        report += `📈 Statistics:\n`;
        report += `  Lines: ${analysis.stats.lines}\n`;
        report += `  Functions: ${analysis.stats.functions}\n`;
        report += `  Types: ${analysis.stats.types}\n\n`;

        // Critical issues
        const criticalIssues = analysis.issues.filter(i => i.severity === 'high');
        if (criticalIssues.length > 0) {
            report += `🚨 Critical Issues (${criticalIssues.length}):\n`;
            criticalIssues.forEach(issue => {
                report += `  Line ${issue.line}: ${issue.description}\n`;
                report += `    Current: ${issue.current}\n\n`;
            });
        }

        // Modernization opportunities
        if (analysis.modernizations.length > 0) {
            report += `🔄 Modernization Opportunities (${analysis.modernizations.length}):\n`;
            analysis.modernizations.forEach(mod => {
                report += `  Line ${mod.line}: ${mod.description}\n`;
                report += `    Current:  ${mod.current}\n`;
                report += `    Improved: ${mod.suggestion}\n\n`;
            });
        }

        // General suggestions
        const suggestions = analysis.suggestions.filter(s => s.severity !== 'high');
        if (suggestions.length > 0) {
            report += `💡 Suggestions (${suggestions.length}):\n`;
            suggestions.slice(0, 10).forEach(suggestion => {
                report += `  Line ${suggestion.line}: ${suggestion.description}\n`;
            });
            if (suggestions.length > 10) {
                report += `  ... and ${suggestions.length - 10} more suggestions\n`;
            }
        }

        return report;
    }

    // CLI interface
    static runCLI() {
        const args = process.argv.slice(2);

        if (args.includes('--help') || args.includes('-h')) {
            console.log('Usage: style-analyzer.js [options] <file.go>');
            console.log('Options:');
            console.log('  --json           Output in JSON format');
            console.log('  --modernize      Focus on modernization suggestions');
            console.log('  --critical       Show only critical issues');
            console.log('  --help           Show this help');
            return;
        }

        const file = args.find(arg => !arg.startsWith('--'));
        if (!file) {
            console.error('Please provide a Go file to analyze');
            process.exit(1);
        }

        const analyzer = new GoStyleAnalyzer();
        const analysis = analyzer.analyzeFile(file);

        if (!analysis) {
            process.exit(1);
        }

        if (args.includes('--json')) {
            console.log(JSON.stringify(analysis, null, 2));
        } else if (args.includes('--critical')) {
            const critical = analysis.issues.filter(i => i.severity === 'high');
            console.log(`Critical issues: ${critical.length}`);
            critical.forEach(issue => {
                console.log(`Line ${issue.line}: ${issue.description}`);
            });
        } else if (args.includes('--modernize')) {
            console.log(`Modernization opportunities: ${analysis.modernizations.length}`);
            analysis.modernizations.forEach(mod => {
                console.log(`Line ${mod.line}: ${mod.description}`);
                console.log(`  Before: ${mod.current}`);
                console.log(`  After:  ${mod.suggestion}`);
            });
        } else {
            console.log(analyzer.generateReport(analysis));
        }
    }
}

// CLI execution
if (require.main === module) {
    GoStyleAnalyzer.runCLI();
}

module.exports = GoStyleAnalyzer;
