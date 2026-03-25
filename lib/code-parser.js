#!/usr/bin/env node

/**
 * Code Flow Parser for openstack-k8s-operators Operators
 * Analyzes Go operator code to extract flow patterns
 */

const fs = require('fs');
const path = require('path');

class OperatorFlowParser {
    constructor() {
        this.controllers = [];
        this.reconcileFunctions = [];
        this.customResources = [];
        this.webhooks = [];
    }

    // Parse operator directory structure
    parseOperatorDirectory(dir) {
        try {
            const result = {
                controllers: this.findControllers(dir),
                reconcilers: this.findReconcilers(dir),
                crds: this.findCRDs(dir),
                webhooks: this.findWebhooks(dir),
                main: this.findMainFunction(dir)
            };

            console.log(JSON.stringify(result, null, 2));
            return result;
        } catch (error) {
            console.error('Error parsing operator:', error.message);
            return null;
        }
    }

    // Find controller files
    findControllers(dir) {
        const controllers = [];
        const controllerPattern = /controller|reconciler/i;

        try {
            this.walkDirectory(dir, (filePath) => {
                if (filePath.endsWith('.go') && controllerPattern.test(filePath)) {
                    const content = fs.readFileSync(filePath, 'utf8');
                    const controller = this.parseControllerFile(filePath, content);
                    if (controller) {
                        controllers.push(controller);
                    }
                }
            });
        } catch (error) {
            console.error('Error finding controllers:', error.message);
        }

        return controllers;
    }

    // Parse individual controller file
    parseControllerFile(filePath, content) {
        const reconcilePattern = /func\s+\(.*?\)\s+Reconcile\s*\([^)]*\)\s+\([^)]*\)/g;
        const setupPattern = /func\s+\([^)]+\)\s+SetupWithManager\s*\([^)]*\)/g;

        const reconcileFunctions = [];
        const setupFunctions = [];

        let match;

        // Find Reconcile functions
        while ((match = reconcilePattern.exec(content)) !== null) {
            reconcileFunctions.push({
                signature: match[0],
                line: this.getLineNumber(content, match.index)
            });
        }

        // Find SetupWithManager functions
        while ((match = setupPattern.exec(content)) !== null) {
            setupFunctions.push({
                signature: match[0],
                line: this.getLineNumber(content, match.index)
            });
        }

        if (reconcileFunctions.length > 0 || setupFunctions.length > 0) {
            return {
                file: path.relative(process.cwd(), filePath),
                reconcile: reconcileFunctions,
                setup: setupFunctions,
                imports: this.extractImports(content),
                structs: this.extractStructs(content)
            };
        }

        return null;
    }

    // Find reconciler functions and their flow
    findReconcilers(dir) {
        const reconcilers = [];

        try {
            this.walkDirectory(dir, (filePath) => {
                if (filePath.endsWith('.go')) {
                    const content = fs.readFileSync(filePath, 'utf8');
                    const flows = this.parseReconcileFlow(filePath, content);
                    if (flows.length > 0) {
                        reconcilers.push({
                            file: path.relative(process.cwd(), filePath),
                            flows: flows
                        });
                    }
                }
            });
        } catch (error) {
            console.error('Error finding reconcilers:', error.message);
        }

        return reconcilers;
    }

    // Parse reconcile function flow
    parseReconcileFlow(filePath, content) {
        const flows = [];
        const signaturePattern = /func\s+\([^)]+\)\s+Reconcile\s*\([^)]*\)\s+\([^)]*\)\s*{/g;

        let match;
        while ((match = signaturePattern.exec(content)) !== null) {
            const bodyStart = match.index + match[0].length;
            const body = this.extractFunctionBody(content, bodyStart);
            const flow = {
                function: match[0].trimEnd().slice(0, -1).trim() + ' {...}',
                line: this.getLineNumber(content, match.index),
                steps: this.extractFlowSteps(body),
                errorHandling: this.extractErrorHandling(body),
                returns: this.extractReturns(body)
            };
            flows.push(flow);
        }

        return flows;
    }

    // Extract function body using brace counting
    extractFunctionBody(content, startIndex) {
        let depth = 1;
        let i = startIndex;
        while (i < content.length && depth > 0) {
            if (content[i] === '{') depth++;
            else if (content[i] === '}') depth--;
            i++;
        }
        return content.substring(startIndex, i - 1);
    }

    // Extract flow steps from reconcile function
    extractFlowSteps(body) {
        const steps = [];

        // Common patterns in reconcile functions
        const patterns = [
            { pattern: /\.\s*Get\s*\(ctx\b[^)]*\)/g, type: 'resource_fetch' },
            { pattern: /\.\s*Create\s*\(ctx\b[^)]*\)/g, type: 'resource_create' },
            { pattern: /\.\s*Update\s*\(ctx\b[^)]*\)/g, type: 'resource_update' },
            { pattern: /\.\s*Delete\s*\(ctx\b[^)]*\)/g, type: 'resource_delete' },
            { pattern: /\.\s*Patch\s*\(ctx\b[^)]*\)/g, type: 'resource_patch' },
            { pattern: /\.Set\s*\(condition\.\w+/g, type: 'condition_set' },
            { pattern: /ctrl\.Result\{[^}]*\}/g, type: 'result_return' },
            { pattern: /controllerutil\.\w+Finalizer/g, type: 'finalizer' },
            { pattern: /helper\.GetConfigMapAndHashWithName/g, type: 'config_map' },
            { pattern: /condition\.CreateList/g, type: 'condition_init' }
        ];

        patterns.forEach(({ pattern, type }) => {
            let match;
            while ((match = pattern.exec(body)) !== null) {
                steps.push({
                    type: type,
                    code: match[0],
                    line: this.getLineNumber(body, match.index)
                });
            }
        });

        return steps.sort((a, b) => a.line - b.line);
    }

    // Extract error handling patterns
    extractErrorHandling(body) {
        const errorPatterns = [];
        const patterns = [
            /if\s+err\s*!=\s*nil\s*{[^}]*}/g,
            /return\s+[^,]*,\s*err/g,
            /ctrl\.Result\{.*\},\s*err/g
        ];

        patterns.forEach(pattern => {
            let match;
            while ((match = pattern.exec(body)) !== null) {
                errorPatterns.push({
                    code: match[0],
                    line: this.getLineNumber(body, match.index)
                });
            }
        });

        return errorPatterns;
    }

    // Extract return statements
    extractReturns(body) {
        const returns = [];
        const returnPattern = /return\s+([^;]+)/g;

        let match;
        while ((match = returnPattern.exec(body)) !== null) {
            returns.push({
                code: match[0],
                value: match[1].trim(),
                line: this.getLineNumber(body, match.index)
            });
        }

        return returns;
    }

    // Find CRD definitions
    findCRDs(dir) {
        const crds = [];

        try {
            this.walkDirectory(dir, (filePath) => {
                if (filePath.endsWith('.yaml') || filePath.endsWith('.yml')) {
                    const content = fs.readFileSync(filePath, 'utf8');
                    if (content.includes('kind: CustomResourceDefinition')) {
                        crds.push({
                            file: path.relative(process.cwd(), filePath),
                            content: this.extractCRDInfo(content)
                        });
                    }
                }
            });
        } catch (error) {
            console.error('Error finding CRDs:', error.message);
        }

        return crds;
    }

    // Extract CRD information
    extractCRDInfo(content) {
        const nameMatch = content.match(/name:\s+([^\n]+)/);
        const groupMatch = content.match(/group:\s+([^\n]+)/);
        const kindMatch = content.match(/kind:\s+([^\n]+)/);

        return {
            name: nameMatch ? nameMatch[1].trim() : null,
            group: groupMatch ? groupMatch[1].trim() : null,
            kind: kindMatch ? kindMatch[1].trim() : null
        };
    }

    // Find webhook configurations
    findWebhooks(dir) {
        const webhooks = [];

        try {
            this.walkDirectory(dir, (filePath) => {
                if (filePath.endsWith('.go')) {
                    const content = fs.readFileSync(filePath, 'utf8');
                    const webhook = this.parseWebhookFile(filePath, content);
                    if (webhook) {
                        webhooks.push(webhook);
                    }
                }
            });
        } catch (error) {
            console.error('Error finding webhooks:', error.message);
        }

        return webhooks;
    }

    // Parse webhook file
    parseWebhookFile(filePath, content) {
        const webhookPatterns = [
            /func\s+\([^)]+\)\s+ValidateCreate\s*\([^)]*\)/g,
            /func\s+\([^)]+\)\s+ValidateUpdate\s*\([^)]*\)/g,
            /func\s+\([^)]+\)\s+ValidateDelete\s*\([^)]*\)/g,
            /func\s+\([^)]+\)\s+Default\s*\([^)]*\)/g
        ];

        const webhooks = [];

        webhookPatterns.forEach(pattern => {
            let match;
            while ((match = pattern.exec(content)) !== null) {
                webhooks.push({
                    function: match[0],
                    line: this.getLineNumber(content, match.index)
                });
            }
        });

        if (webhooks.length > 0) {
            return {
                file: path.relative(process.cwd(), filePath),
                webhooks: webhooks
            };
        }

        return null;
    }

    // Find main function
    findMainFunction(dir) {
        try {
            const candidates = [
                path.join(dir, 'main.go'),
                path.join(dir, 'cmd', 'main.go')
            ];
            for (const mainPath of candidates) {
                if (fs.existsSync(mainPath)) {
                    const content = fs.readFileSync(mainPath, 'utf8');
                    return this.parseMainFunction(content);
                }
            }
        } catch (error) {
            console.error('Error finding main function:', error.message);
        }

        return null;
    }

    // Parse main function
    parseMainFunction(content) {
        const setupPattern = /mgr\.Add\([^)]+\)/g;
        const controllerPattern = /\.SetupWithManager\([^)]+\)/g;

        const setup = [];
        let match;

        while ((match = setupPattern.exec(content)) !== null) {
            setup.push({
                code: match[0],
                line: this.getLineNumber(content, match.index)
            });
        }

        while ((match = controllerPattern.exec(content)) !== null) {
            setup.push({
                code: match[0],
                line: this.getLineNumber(content, match.index)
            });
        }

        return {
            setup: setup.sort((a, b) => a.line - b.line),
            imports: this.extractImports(content)
        };
    }

    // Utility functions
    walkDirectory(dir, callback) {
        if (!fs.existsSync(dir)) return;

        const files = fs.readdirSync(dir);
        files.forEach(file => {
            const filePath = path.join(dir, file);
            const stat = fs.statSync(filePath);

            if (stat.isDirectory() && !file.startsWith('.') && file !== 'vendor') {
                this.walkDirectory(filePath, callback);
            } else if (stat.isFile()) {
                callback(filePath);
            }
        });
    }

    extractImports(content) {
        const importPattern = /import\s*\(\s*([^)]*)\s*\)/s;
        const match = importPattern.exec(content);
        if (match) {
            return match[1].split('\n').map(line => line.trim()).filter(line => line);
        }
        return [];
    }

    extractStructs(content) {
        const structPattern = /type\s+(\w+)\s+struct\s*{([^}]*)}/g;
        const structs = [];

        let match;
        while ((match = structPattern.exec(content)) !== null) {
            structs.push({
                name: match[1],
                fields: match[2].trim(),
                line: this.getLineNumber(content, match.index)
            });
        }

        return structs;
    }

    getLineNumber(content, index) {
        return content.substring(0, index).split('\n').length;
    }
}

// CLI interface
if (require.main === module) {
    const args = process.argv.slice(2);
    const dir = args[0] || process.cwd();

    if (args.includes('--help') || args.includes('-h')) {
        console.log('Usage: code-parser.js [directory]');
        console.log('  directory: Path to operator code (default: current directory)');
        process.exit(0);
    }

    const parser = new OperatorFlowParser();
    parser.parseOperatorDirectory(dir);
}

module.exports = OperatorFlowParser;
