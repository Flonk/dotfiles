const fs = require("fs");
const commands = JSON.parse(fs.readFileSync("./commands.json"));
const keys = Object.keys(commands);
const choice = process.argv[2];

if (!choice) {
  console.log(keys.join("\n"));
  process.exit(0);
}

const command = keys.find((key) => key.startsWith(choice));

if (command) {
  console.log(commands[command]);
} else {
  console.log("No command found");
  process.exit(1);
}
