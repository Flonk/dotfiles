import { Box, Text } from "ink";
import type { StepInfo } from "./lib/types.js";

const STATUS_COLOR: Record<StepInfo["status"], string> = {
  pending: "gray",
  running: "blue",
  done: "green",
  error: "red",
  skipped: "gray",
};

interface Props {
  steps: StepInfo[];
}

export function StepList({ steps }: Props) {
  return (
    <Box flexDirection="column">
      {steps.map((step, i) => {
        const color = STATUS_COLOR[step.status];
        return (
          <Box key={i}>
            <Text color={color} bold={step.status === "running"}>{step.label}</Text>
          </Box>
        );
      })}
    </Box>
  );
}
