import fs from 'fs/promises';
import path from 'path';
import prompts from 'prompts';

const __projectDir = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const myPackage = JSON.parse(await fs.readFile(path.resolve(__projectDir, 'package.json'), 'utf8'));

const oldName = myPackage.pythonPackageName || myPackage.name;
const ignoreFolders = ['node_modules', '__pycache__', 'tests/__pycache__/', '.git', '.ruff_cache', '.next', 'coverage', 'dist'];
let rewriteFileNameStatus = 'ask';
let rewriteFileContentsStatus = 'ask';

async function walk(dir, oldName, newName) {
    if (oldName === newName) {
        return;
    }

    for await (const file of await fs.readdir(dir)) {
        const pathToFile = path.join(dir, file);

        const isDirectory = (await fs.stat(pathToFile)).isDirectory();
        if (isDirectory && ignoreFolders.includes(file)) continue;

        if (isDirectory) {
            await walk(pathToFile, oldName, newName);
        } else {
            await maybeChangeFileContents(pathToFile, oldName, newName);
            await maybeRenameFile(pathToFile, oldName, newName);
        }
    }
}

async function askToReplace(prompt) {
    const response = await prompts({
        type: 'select',
        name: 'value',
        message: prompt,
        choices: [
            { title: 'Yes', value: 'yes' },
            { title: 'No', value: 'no' },
            { title: 'Yes to all', value: 'all' },
            { title: 'No to all', value: 'none' },
        ],
    });
    return response.value;
}

async function maybeChangeFileContents(dir, oldName, newName) {
    const data = await fs.readFile(dir, 'utf8');

    if (!data.includes(oldName)) return;

    if (rewriteFileContentsStatus === 'none') {
        console.log(`  - Skipped replacing ${oldName} with ${newName} in ${dir}`);
        return;
    } else if (rewriteFileContentsStatus === 'ask') {
        const response = await askToReplace(`Replace ${oldName} with ${newName} in ${dir.replace(__projectDir, '')}?`);

        if (response === 'all') {
            console.log(`  - Rewriting all file contents`);
            rewriteFileContentsStatus = 'all';
        } else if (response === 'none') {
            console.log(`  - Skipped replacing ${oldName} with ${newName} in ${dir}`);
            rewriteFileContentsStatus = 'none';
            return
        } else if (response === 'no') {
            console.log(`  - Skipped replacing ${oldName} with ${newName} in ${dir}`);
            return;
        }
    }

    const result = data.replace(new RegExp(oldName, 'g'), newName);
    await fs.writeFile(dir, result);
    console.log(`  - Replaced ${oldName} with ${newName} in ${dir}`);
}

async function maybeRenameFile(dir, oldName, newName) {

    // We only want to replace the oldName in the basename of the full file path
    // So, don't change "tabnab" in /Users/tabnab/Documents/foobar.txt
    // Bu do change "tabnab" in /Users/tabnab/Documents/tabnab1.txt (tabnab.txt -> foobar1.txt)
    // const newDir = dir.replace(oldName, newName);
    const newDir = path.join(path.dirname(dir), path.basename(dir).replace(oldName, newName));

    if (dir === newDir) return;

    try {
        await fs.access(newDir);
        console.log(`  - ${newDir} already exists`);
        return;
    } catch { /* Destination doesn't exist - proceed */ }

    if (rewriteFileNameStatus === 'none') {
        console.log(`  - Skipped renaming ${dir} to ${newDir}`);
        return;
    } else if (rewriteFileNameStatus === 'ask') {
        const response = await askToReplace(`Rename ${dir.replace(__projectDir, '')} to ${newDir.replace(__projectDir, '')}?`);
        if (response === 'all') {
            console.log(`  - Rewriting all file names`);
            rewriteFileNameStatus = 'all';
        } else if (response === 'none') {
            console.log(`  - Skipped renaming ${dir} to ${newDir}`);
            rewriteFileNameStatus = 'none';
            return
        } else if (response === 'no') {
            console.log(`  - Skipped renaming ${dir} to ${newDir}`);
            return;
        }
    }

    await fs.rename(dir, newDir);
    console.log(`  - Renamed ${dir} to ${newDir}`);
}

async function updateDescription(description) {
    myPackage.description = description
    // Update the package.json file
    await fs.writeFile(path.resolve(__projectDir, 'package.json'), JSON.stringify(myPackage, null, 2));

    // Update the manifest.json file
    const manifestFilePath = path.resolve(__projectDir, 'manifest.json');
    if (await fs.access(manifestFilePath)) {
        const manifestJson = JSON.parse(await fs.readFile(manifestFilePath, 'utf8'));
        manifestJson.description = description
        await fs.writeFile(manifestFilePath, JSON.stringify(manifestJson, null, 2));
    }
}

// ---- Main Script Execution ---- 
(async () => {
    // ask for name and description
    const { newName, description } = await prompts([
        {
            type: 'text',
            name: 'newName',
            message: `What would you like to rename ${oldName} to?`,
            initial: path.basename(__projectDir),
        },
        {
            type: 'text',
            name: 'description',
            message: 'Enter a description for the project',
        }
    ]);

    if (!newName) {
        console.log("No new name provided. Exiting.");
        process.exit(1);
    }

    if (!description) {
        console.log("No description provided. Exiting.");
        process.exit(1);
    }

    let rewriteFileNameStatus = 'ask';
    let rewriteFileContentsStatus = 'ask';

    updateDescription(description);

    try {
        await walk(__projectDir, oldName, newName, rewriteFileNameStatus, rewriteFileContentsStatus);
    } catch (error) {
        console.error("An error occurred during the project walk:", error);
    }
})();
