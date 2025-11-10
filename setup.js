const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { execSync } = require("node:child_process");

// --- Configuration Constants ---

const DEFAULT_USERNAME = "DailyDriver";
const POWERSHELL_PROFILE = "Microsoft.PowerShell_profile.ps1";
const ARCHIVE_DIR = path.join(".", "env");

const SCOOP_INSTALLER_URL = "https://get.scoop.sh";
const SCOOP_INSTALLER_SCRIPT = path.join(".", "InstallScoop.ps1");
const SCOOP_PACKAGES = [
  "7zip",
  "adb",
  "bun",
  "cloc",
  "dotnet-sdk",
  "dotnet-sdk-preview",
  "fastfetch",
  "ffmpeg",
  "gh",
  "git",
  "jq",
  "nodejs",
  "oh-my-posh",
  "python@3.13.9",
  "wget",
];

const PYTORCH_INDEX_URL = "https://download.pytorch.org/whl/cu130";
const PYTORCH_PACKAGES = ["torch", "torchvision"];
const PYTHON_PACKAGES = [
  "git+https://github.com/giampaolo/psutil",
  "git+https://github.com/googleapis/python-genai",
  "git+https://github.com/spotDL/spotify-downloader",
  "git+https://github.com/yt-dlp/yt-dlp",
  "git+https://github.com/Yujia-Yan/Transkun",
];

const NPM_PACKAGES = ["@google/gemini-cli"];

const OH_MY_POSH_THEME_URL =
  "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomicBit.omp.json";

const MANAGE_JUNCTIONS_SCRIPT = path.join(".", "ManageJunctions.ps1");
const RECREATE_JUNCTIONS_SCRIPT = path.join(".", "RecreateJunctions.ps1");
const EXPORT_ENVIRONMENT_SCRIPT = path.join(".", "ExportEnvironment.ps1");

const PWSH_EXEC_ARGS = [
  "pwsh.exe",
  "-ExecutionPolicy",
  "Bypass",
  "-NoProfile",
  "-NoLogo",
];
const PWSH_FILE_ARGS = [...PWSH_EXEC_ARGS, "-File"];
const PWSH_COMMAND_ARGS = [...PWSH_EXEC_ARGS, "-Command"];

/**
 * Converts an array of command-line arguments into a single string,
 * properly escaped according to MS C runtime parsing rules for Windows.
 * This ensures that arguments with spaces or special characters are
 * correctly interpreted when passed to a child process.
 *
 * @param {string[]} args - An array of strings, where each string is a command-line argument.
 * @returns {string} - A single, properly escaped command-line string suitable for execution on Windows.
 */
function list2cmdline(args) {
  const cmdline = [];

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    let backslashes = [];
    let needs_quotes = arg === "" || /\s/.test(arg);

    if (i > 0) {
      cmdline.push(" ");
    }

    if (needs_quotes) {
      cmdline.push('"');
    }

    for (let j = 0; j < arg.length; j++) {
      const char = arg[j];

      if (char === "\\") {
        backslashes.push(char);
      } else if (char === '"') {
        cmdline.push("\\".repeat(backslashes.length * 2));
        backslashes = [];
        cmdline.push('\\"');
      } else {
        if (backslashes.length > 0) {
          cmdline.push(...backslashes);
          backslashes = [];
        }
        cmdline.push(char);
      }
    }

    if (backslashes.length > 0) {
      if (needs_quotes) {
        cmdline.push("\\".repeat(backslashes.length * 2));
      } else {
        cmdline.push(...backslashes);
      }
    }

    if (needs_quotes) {
      cmdline.push('"');
    }
  }

  return cmdline.join("");
}

/**
 * Prints a formatted heading to the console, typically used to demarcate different
 * stages or sections of the script's execution for better readability.
 * The heading includes a top and bottom border made of hyphens.
 * @param {string} content - The text content to be displayed as the heading.
 */
function write_heading(content) {
  const border = "-".repeat(content.length);
  console.log(border);
  console.log(content);
  console.log(border);
}

/**
 * Executes a given command synchronously in the shell and pipes its standard output
 * and standard error to the console. It uses `list2cmdline` to properly escape
 * the command arguments for Windows execution.
 * @param {string[]} args An array where the first element is the commandand subsequent elements are its arguments.
 * @throws {Error} Throws an error if the command execution fails.
 */
function run_command(args) {
  const command = list2cmdline(args);
  console.log(`> Executing: ${command}`);
  try {
    execSync(command, { stdio: "inherit" });
  } catch (error) {
    // robocopy often returns non-zero exit codes even on success,
    // so we don't want to terminate the script
    if (args[0] === "robocopy.exe") {
      return;
    }
    throw error;
  }
}

// --- Main Script Logic ---
async function main() {
  const local_username = process.env.LOCAL_USERNAME || DEFAULT_USERNAME;
  const local_userprofile = path.join("C:\\Users", local_username);
  const scoop_dir = path.join(local_userprofile, "scoop");
  const scoop_ps1 = path.join(scoop_dir, "shims", "scoop.ps1");
  const pip_exe = path.join(
    scoop_dir,
    "apps",
    "python",
    "current",
    "Scripts",
    "pip.exe"
  );
  const bun_cmd = path.join(scoop_dir, "apps", "bun", "current", "bun.exe");

  // --- Install Scoop ---
  write_heading("Installing Scoop...");
  fs.mkdirSync(scoop_dir, { recursive: true });

  console.log(`Downloading Scoop installer from ${SCOOP_INSTALLER_URL}...`);
  const response = await fetch(SCOOP_INSTALLER_URL);
  const installer_script_content = await response.text();
  fs.writeFileSync(SCOOP_INSTALLER_SCRIPT, installer_script_content, {
    encoding: "utf8",
  });

  run_command([
    ...PWSH_FILE_ARGS,
    SCOOP_INSTALLER_SCRIPT,
    "-ScoopDir",
    scoop_dir,
  ]);

  // --- Install Scoop Packages ---
  if (process.env.INSTALL_SCOOP_PACKAGES === "on") {
    write_heading("Adding additional bucket(s)...");
    run_command([...PWSH_COMMAND_ARGS, `& ${scoop_ps1} bucket add versions`]);

    write_heading("Updating Scoop...");
    run_command([...PWSH_COMMAND_ARGS, `& ${scoop_ps1} update`]);

    write_heading("Installing Scoop packages...");
    run_command([
      ...PWSH_COMMAND_ARGS,
      `& ${scoop_ps1} install`,
      ...SCOOP_PACKAGES,
    ]);

    write_heading("Purging package cache...");
    run_command([...PWSH_COMMAND_ARGS, `& ${scoop_ps1} cache rm *`]);
  }

  // --- Install NPM Packages ---
  if (process.env.INSTALL_NPM_PACKAGES === "on") {
    write_heading("Installing Bun packages...");
    run_command([bun_cmd, "add", "-g", ...NPM_PACKAGES]);
  }

  // --- Install Python Packages ---
  if (
    process.env.INSTALL_PYTHON_PACKAGES === "on" &&
    fs.existsSync(scoop_ps1) &&
    fs.existsSync(pip_exe)
  ) {
    write_heading("Installing Python packages (stage 1 of 2)...");
    const pytorch_args = [
      "install",
      ...PYTORCH_PACKAGES,
      "--index-url",
      PYTORCH_INDEX_URL,
    ];
    run_command([pip_exe, ...pytorch_args]);

    write_heading("Installing Python packages (stage 2 of 2)...");
    const python_args = ["install", ...PYTHON_PACKAGES];
    run_command([pip_exe, ...python_args]);
  }

  // --- Export PowerShell Profile Configuration ---
  write_heading("Exporting configuration to PowerShell profile...");
  run_command([
    ...PWSH_FILE_ARGS,
    EXPORT_ENVIRONMENT_SCRIPT,
    "-OhMyPoshThemeUrl",
    OH_MY_POSH_THEME_URL,
    "-PowershellProfileName",
    POWERSHELL_PROFILE,
  ]);

  // --- Manage Junctions ---
  write_heading("Managing junctions...");
  run_command([...PWSH_FILE_ARGS, MANAGE_JUNCTIONS_SCRIPT, "-Path", scoop_dir]);

  // --- Archive Contents ---
  write_heading("Copying contents for archiving...");
  fs.mkdirSync(ARCHIVE_DIR, { recursive: true });
  fs.copyFileSync(
    POWERSHELL_PROFILE,
    path.join(ARCHIVE_DIR, POWERSHELL_PROFILE)
  );

  if (fs.existsSync(RECREATE_JUNCTIONS_SCRIPT)) {
    fs.copyFileSync(
      RECREATE_JUNCTIONS_SCRIPT,
      path.join(ARCHIVE_DIR, RECREATE_JUNCTIONS_SCRIPT)
    );
  }

  const robocopy_args = [
    scoop_dir,
    path.join(ARCHIVE_DIR, "scoop"),
    "/e",
    `/mt:${os.cpus().length}`,
    "/nc",
    "/ndl",
    "/nfl",
    "/np",
    "/ns",
    "/xj",
  ];
  run_command(["robocopy.exe", ...robocopy_args]);
}

main().catch((error) => {
  console.error("\n--- SCRIPT FAILED ---");
  console.error(error.message);
  process.exit(1);
});
