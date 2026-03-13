#!/usr/bin/env tsx

import chalk from "chalk";
import inquirer from "inquirer";
import { $ } from "zx";

$.verbose = false;

const banner = `
┏━╸╻┏┓╻┏━╸┏━╸┏━┓┏━┓┏━┓╻┏┓╻╺┳╸   ┏━┓┏━╸╺┳╸╻ ╻┏━┓
┣╸ ┃┃┗┫┃╺┓┣╸ ┣┳┛┣━┛┣┳┛┃┃┗┫ ┃    ┗━┓┣╸  ┃ ┃ ┃┣━┛
╹  ╹╹ ╹┗━┛┗━╸╹┗╸╹  ╹┗╸╹╹ ╹ ╹    ┗━┛┗━╸ ╹ ┗━┛╹  
`;

const fingers = [
  { name: "Left Thumb", value: "left-thumb" },
  { name: "Left Index", value: "left-index-finger" },
  { name: "Left Middle", value: "left-middle-finger" },
  { name: "Left Ring", value: "left-ring-finger" },
  { name: "Left Little", value: "left-little-finger" },
  { name: "Right Thumb", value: "right-thumb" },
  { name: "Right Index", value: "right-index-finger" },
  { name: "Right Middle", value: "right-middle-finger" },
  { name: "Right Ring", value: "right-ring-finger" },
  { name: "Right Little", value: "right-little-finger" },
];

async function main() {
  console.log(chalk.cyan(banner));

  const { selectedFingers } = await inquirer.prompt([
    {
      type: "checkbox",
      name: "selectedFingers",
      message: "Select which fingers you want to enroll:",
      choices: fingers,
    },
  ]);

  if (selectedFingers.length === 0) {
    console.log(chalk.red("\nNo fingers selected. Exiting."));
    return;
  }

  console.log(
    chalk.green(`\nEnrolling ${selectedFingers.length} finger(s)...\n`),
  );

  // Get current username
  const username = process.env.USER || process.env.USERNAME || "root";

  // Stop fprintd service to release the device
  console.log(chalk.yellow("Stopping fprintd service..."));
  try {
    await $`sudo systemctl stop fprintd.service`;
  } catch (error) {
    console.log(
      chalk.yellow("Could not stop fprintd service (may not be running)"),
    );
  }

  for (const finger of selectedFingers) {
    console.log(chalk.cyan(`\n📍 Enrolling: ${finger}`));
    console.log(chalk.gray("Follow the prompts to scan your finger...\n"));

    try {
      await $`sudo fprintd-enroll -f ${finger} ${username}`.pipe(
        process.stdout,
      );
      console.log(chalk.green(`✓ ${finger} enrolled successfully!`));
    } catch (error) {
      console.log(chalk.red(`✗ Failed to enroll ${finger}`));
    }
  }

  // Restart fprintd service
  console.log(chalk.yellow("\nRestarting fprintd service..."));
  try {
    await $`sudo systemctl start fprintd.service`;
  } catch (error) {
    console.log(chalk.yellow("Could not restart fprintd service"));
  }

  console.log(chalk.green("\n✓ Fingerprint enrollment complete!"));
}

main().catch((error) => {
  console.error(chalk.red("Error:"), error);
  process.exit(1);
});
