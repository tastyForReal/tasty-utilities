// Import required Node.js modules
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { execSync } = require("node:child_process");

// --- Configuration Constants ---

const DEFAULT_USERNAME = "DailyDriver";
const POWERSHELL_PROFILE_FILENAME = "Microsoft.PowerShell_profile.ps1";
const ARCHIVE_DIR = ".\\env";

const SCOOP_INSTALLER_URL = "https://get.scoop.sh";
const SCOOP_INSTALLER_SCRIPT = ".\\InstallScoop.ps1";
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

const NPM_PACKAGES = "@google/gemini-cli";

const OH_MY_POSH_THEME_URL =
  "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomicBit.omp.json";

const MANAGE_JUNCTIONS_SCRIPT = ".\\ManageJunctions.ps1";
const RECREATE_JUNCTIONS_SCRIPT = ".\\RecreateJunctions.ps1";

/**
 * Writes a formatted heading to the console.
 * @param {string} content The text content of the heading.
 */
function write_heading(content) {
  const border = "-".repeat(content.length);
  console.log(border);
  console.log(content);
  console.log(border);
}

/**
 * Executes a command synchronously and prints its output to the console.
 * @param {string} command The command to execute.
 */
function run_command(command) {
  console.log(`\n> Executing: ${command}`);
  execSync(command, { stdio: "inherit" });
}

// --- Main Script Logic ---

async function main() {
  // Determine user profile path
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
    encoding: "ascii",
  });

  run_command(
    `pwsh.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File ".\\${SCOOP_INSTALLER_SCRIPT}" -ScoopDir "${scoop_dir}"`
  );

  // --- Install Scoop Packages (Conditional) ---
  if (process.env.INSTALL_SCOOP_PACKAGES === "on") {
    write_heading("Adding additional bucket(s)...");
    run_command(`pwsh.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -Command "& '${scoop_ps1}' bucket add versions"`);

    write_heading("Updating Scoop...");
    run_command(`pwsh.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -Command "& '${scoop_ps1}' update"`);

    write_heading("Installing Scoop packages...");
    run_command(`pwsh.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -Command "& '${scoop_ps1}' install ${SCOOP_PACKAGES.join(" ")}"`);

    write_heading("Purging package cache...");
    run_command(`pwsh.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -Command "& '${scoop_ps1}' cache rm *"`);
  }

  // --- Install NPM Packages (Conditional) ---
  if (process.env.INSTALL_NPM_PACKAGES === "on") {
    write_heading("Installing Bun packages...");
    run_command(`"${bun_cmd}" add -g ${NPM_PACKAGES}`);
  }

  // --- Install Python Packages (Conditional) ---
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
    run_command(`"${pip_exe}" ${pytorch_args.join(" ")}`);

    write_heading("Installing Python packages (stage 2 of 2)...");
    const python_args = ["install", ...PYTHON_PACKAGES];
    run_command(`"${pip_exe}" ${python_args.join(" ")}`);
  }

  // --- Export PowerShell Profile Configuration ---
  write_heading("Exporting configuration to PowerShell profile...");
  const path_env = process.env.Path || "";
  const scoop_paths = path_env
    .split(";")
    .filter((p) => p.toLowerCase().includes("scoop"));

  const profile_content = [
    `$env:Path += ";${scoop_paths.join(";")}"`,
    `oh-my-posh init pwsh --config "${OH_MY_POSH_THEME_URL}" | Invoke-Expression`,
  ].join("\n");

  fs.writeFileSync(POWERSHELL_PROFILE_FILENAME, profile_content, {
    encoding: "ascii",
  });
  console.log(fs.readFileSync(POWERSHELL_PROFILE_FILENAME, "utf-8"));

  // --- Manage Junctions ---
  write_heading("Managing junctions...");
  run_command(
    `pwsh.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File ".\\${MANAGE_JUNCTIONS_SCRIPT}" -Path "${scoop_dir}"`
  );

  // --- Archive Contents ---
  write_heading("Copying contents for archiving...");
  fs.mkdirSync(ARCHIVE_DIR, { recursive: true });
  fs.copyFileSync(
    POWERSHELL_PROFILE_FILENAME,
    path.join(ARCHIVE_DIR, POWERSHELL_PROFILE_FILENAME)
  );

  if (fs.existsSync(RECREATE_JUNCTIONS_SCRIPT)) {
    fs.copyFileSync(
      RECREATE_JUNCTIONS_SCRIPT,
      path.join(ARCHIVE_DIR, RECREATE_JUNCTIONS_SCRIPT)
    );
  }

  const robocopy_args = [
    `"${scoop_dir}"`,
    `"${path.join(ARCHIVE_DIR, "scoop")}"`,
    "/e",
    `/mt:${os.cpus().length}`,
    "/nc",
    "/ndl",
    "/nfl",
    "/np",
    "/ns",
    "/xj",
  ];
  run_command(`robocopy.exe ${robocopy_args.join(" ")}`);
}

// Run the main function and handle potential errors
main().catch((error) => {
  console.error("\n--- SCRIPT FAILED ---");
  console.error(error.message);
  process.exit(1);
});
