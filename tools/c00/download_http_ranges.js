#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const { spawn, spawnSync } = require("child_process");
const { pipeline } = require("stream/promises");

const args = parseArgs(process.argv.slice(2));

if (args.help || args.h) {
	usage();
	process.exit(0);
}

const url = String(args.url || args._[0] || "");
const output = path.resolve(String(args.output || args.o || ""));
const parts = Math.max(1, Number(args.parts || process.env.C00_PARALLEL_DOWNLOAD_PARTS || 8));
const minPartSize = Math.max(1024 * 1024, Number(args["min-part-size"] || 8 * 1024 * 1024));

if (!url || !output) {
	usage();
	process.exit(2);
}

main().catch((error) => {
	console.error(error && error.stack ? error.stack : String(error));
	process.exit(1);
});


async function main() {
	if (!commandExists("curl")) {
		throw new Error("curl is required for range downloads.");
	}

	const metadata = readRemoteMetadata(url);
	if (!metadata.contentLength || metadata.contentLength <= 0) {
		throw new Error(`Could not determine remote content-length for ${url}.`);
	}
	if (metadata.acceptRanges && !/bytes/i.test(metadata.acceptRanges)) {
		throw new Error(`Remote server does not advertise byte ranges: ${metadata.acceptRanges}`);
	}

	const existingSize = fileSize(output);
	if (existingSize === metadata.contentLength) {
		console.log(`OK   existing output is complete: ${output} (${existingSize} bytes)`);
		return;
	}

	const actualParts = Math.max(1, Math.min(parts, Math.ceil(metadata.contentLength / minPartSize)));
	const partDir = `${output}.parts`;
	fs.mkdirSync(path.dirname(output), { recursive: true });
	fs.mkdirSync(partDir, { recursive: true });

	console.log(`Range download: ${url}`);
	console.log(`Output: ${output}`);
	console.log(`Size: ${metadata.contentLength} bytes`);
	console.log(`Parts: ${actualParts}`);

	const ranges = splitRanges(metadata.contentLength, actualParts);
	await Promise.all(ranges.map((range, index) => downloadPart(url, partDir, index, range)));
	await assembleParts(output, partDir, ranges);
	verifyOutput(output, metadata.contentLength);
	console.log(`OK   range download complete: ${output}`);
}


function parseArgs(argv) {
	const parsed = { _: [] };
	for (let index = 0; index < argv.length; index += 1) {
		const item = argv[index];
		if (!item.startsWith("--")) {
			parsed._.push(item);
			continue;
		}
		const key = item.slice(2);
		const next = argv[index + 1];
		if (!next || next.startsWith("--")) {
			parsed[key] = true;
		} else {
			parsed[key] = next;
			index += 1;
		}
	}
	return parsed;
}


function usage() {
	console.error([
		"Usage:",
		"  node tools/c00/download_http_ranges.js --url <url> --output <file> [--parts 8]",
		"",
		"Downloads a large HTTP object with byte-range requests and resumable part files.",
		"Used for slow Godot export template/editor downloads on device machines.",
	].join("\n"));
}


function commandExists(name) {
	const result = spawnSync(name, ["--version"], { stdio: "ignore" });
	return result.status === 0;
}


function readRemoteMetadata(targetUrl) {
	const curlArgs = ["-sS", "-I", "-L", "--connect-timeout", process.env.C00_CURL_CONNECT_TIMEOUT || "30"];
	if (process.env.C00_CURL_HTTP1 === "1") {
		curlArgs.push("--http1.1");
	}
	curlArgs.push(targetUrl);
	const result = spawnSync("curl", curlArgs, { encoding: "utf8" });
	if (result.status !== 0) {
		throw new Error(`curl HEAD failed for ${targetUrl}\n${result.stderr || result.stdout}`);
	}

	const headers = `${result.stdout}\n${result.stderr || ""}`.split(/\r?\n/);
	let contentLength = 0;
	let acceptRanges = "";
	for (const line of headers) {
		const match = /^([^:]+):\s*(.*)$/.exec(line);
		if (!match) {
			continue;
		}
		const key = match[1].toLowerCase();
		const value = match[2].trim();
		if (key === "content-length") {
			const parsed = Number(value);
			if (Number.isFinite(parsed) && parsed > 0) {
				contentLength = parsed;
			}
		}
		if (key === "accept-ranges") {
			acceptRanges = value;
		}
	}
	return { contentLength, acceptRanges };
}


function splitRanges(totalSize, count) {
	const ranges = [];
	const chunkSize = Math.ceil(totalSize / count);
	for (let index = 0; index < count; index += 1) {
		const start = index * chunkSize;
		const end = Math.min(totalSize - 1, start + chunkSize - 1);
		if (start <= end) {
			ranges.push({ start, end, expected: end - start + 1 });
		}
	}
	return ranges;
}


async function downloadPart(targetUrl, partDir, index, range) {
	const partPath = path.join(partDir, `${String(index).padStart(4, "0")}.part`);
	await foldAppendFiles(partPath, partDir, index);
	let existing = fileSize(partPath);
	if (existing > range.expected) {
		fs.unlinkSync(partPath);
		existing = 0;
	}
	const maxAttempts = Math.max(1, Number(process.env.C00_RANGE_PART_ATTEMPTS || 20));
	for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
		existing = fileSize(partPath);
		if (existing === range.expected) {
			console.log(`OK   part ${index + 1}: complete (${range.expected} bytes)`);
			return;
		}
		if (existing > range.expected) {
			fs.unlinkSync(partPath);
			existing = 0;
		}

		const rangeStart = range.start + existing;
		const appendPath = path.join(partDir, `${String(index).padStart(4, "0")}.${process.pid}.${Date.now()}.append`);
		const curlArgs = curlDownloadArgs();
		curlArgs.push("--range", `${rangeStart}-${range.end}`, "-o", appendPath, targetUrl);
		console.log(`GET  part ${index + 1}/${attempt}: bytes ${rangeStart}-${range.end}`);
		try {
			await run("curl", curlArgs);
		} catch (error) {
			await foldAppendFiles(partPath, partDir, index);
			if (attempt === maxAttempts) {
				throw error;
			}
			continue;
		}
		await foldAppendFiles(partPath, partDir, index);
	}

	const finalSize = fileSize(partPath);
	if (finalSize !== range.expected) {
		throw new Error(`Part ${index + 1} has ${finalSize} bytes, expected ${range.expected}.`);
	}
	console.log(`OK   part ${index + 1}: ${finalSize} bytes`);
}


function curlDownloadArgs() {
	const curlArgs = [
		"-sS",
		"--show-error",
		"-L",
		"--fail",
		"--retry",
		process.env.C00_RANGE_CURL_RETRY || "0",
		"--retry-delay",
		process.env.C00_RANGE_CURL_RETRY_DELAY || process.env.C00_CURL_RETRY_DELAY || "10",
		"--connect-timeout",
		process.env.C00_CURL_CONNECT_TIMEOUT || "30",
	];
	if ((process.env.C00_CURL_RETRY_ALL_ERRORS || "1") !== "0") {
		curlArgs.push("--retry-all-errors");
	}
	if (process.env.C00_CURL_HTTP1 === "1") {
		curlArgs.push("--http1.1");
	}
	if (process.env.C00_CURL_MAX_TIME) {
		curlArgs.push("--max-time", process.env.C00_CURL_MAX_TIME);
	}
	return curlArgs;
}


function run(command, commandArgs) {
	return new Promise((resolve, reject) => {
		const child = spawn(command, commandArgs, { stdio: ["ignore", "inherit", "inherit"] });
		child.on("error", reject);
		child.on("exit", (code) => {
			if (code === 0) {
				resolve();
			} else {
				reject(new Error(`${command} exited with ${code}`));
			}
		});
	});
}


async function appendFile(target, source) {
	await pipeline(
		fs.createReadStream(source),
		fs.createWriteStream(target, { flags: "a" }),
	);
}


async function foldAppendFiles(partPath, partDir, index) {
	const prefix = `${String(index).padStart(4, "0")}.`;
	const files = fs.existsSync(partDir)
		? fs.readdirSync(partDir)
			.filter((name) => name.startsWith(prefix) && name.endsWith(".append"))
			.sort()
		: [];
	for (const file of files) {
		const appendPath = path.join(partDir, file);
		if (fileSize(appendPath) > 0) {
			await appendFile(partPath, appendPath);
		}
		fs.unlinkSync(appendPath);
	}
}


async function assembleParts(output, partDir, ranges) {
	const tmpOutput = `${output}.tmp-${process.pid}`;
	const write = fs.createWriteStream(tmpOutput);
	try {
		for (let index = 0; index < ranges.length; index += 1) {
			const partPath = path.join(partDir, `${String(index).padStart(4, "0")}.part`);
			await pipeline(fs.createReadStream(partPath), write, { end: false });
		}
		await new Promise((resolve, reject) => {
			write.end(resolve);
			write.on("error", reject);
		});
		fs.renameSync(tmpOutput, output);
	} catch (error) {
		write.destroy();
		try {
			fs.unlinkSync(tmpOutput);
		} catch (_) {
			// Leave the original error intact.
		}
		throw error;
	}
}


function verifyOutput(output, expectedSize) {
	const actualSize = fileSize(output);
	if (actualSize !== expectedSize) {
		throw new Error(`Output has ${actualSize} bytes, expected ${expectedSize}.`);
	}
}


function fileSize(filePath) {
	try {
		return fs.statSync(filePath).size;
	} catch (_) {
		return 0;
	}
}
