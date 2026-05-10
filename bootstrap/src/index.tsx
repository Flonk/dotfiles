import { Box, render, Text } from "ink";
import { BootstrapProvider, useBootstrap } from "./context.js";
import { StepList } from "./StepList.js";
import { Step1 } from "./steps/1-installation/Step1.js";
import { Step2 } from "./steps/2-connect/Step2.js";
import { Step3 } from "./steps/3-nixos-check/Step3.js";
import { Step4 } from "./steps/4-add-config/Step4.js";
import { Step5 } from "./steps/5-install/Step5.js";
import { Step6 } from "./steps/6-create-user/Step6.js";

const BANNER = `┏━┓╻┏ ╻ ╻┏┓╻┏━╸╺┳╸
┗━┓┣┻┓┗┳┛┃┗┫┣╸  ┃
┗━┛╹ ╹ ╹ ╹ ╹┗━╸ ╹
BOOTSTRAP SCRIPT v1`;

function ActiveStep() {
  const { currentStep, phase, statusMsg, errorMsg } = useBootstrap();

  if (phase === "error") {
    return (
      <Box paddingX={1}>
        <Text bold>Bootstrap failed: {errorMsg}</Text>
      </Box>
    );
  }

  if (phase === "done") {
    return (
      <Box paddingX={1}>
        <Text bold>Bootstrap complete! Welcome to skynet.</Text>
      </Box>
    );
  }

  return (
    <Box flexDirection="column">
      {currentStep === 1 && <Step1 />}
      {currentStep === 2 && <Step2 />}
      {currentStep === 3 && <Step3 />}
      {currentStep === 4 && <Step4 />}
      {currentStep === 5 && <Step5 />}
      {currentStep === 6 && <Step6 />}

      {statusMsg && (
        <Box paddingX={1}>
          <Text color="yellow">{statusMsg}</Text>
        </Box>
      )}
    </Box>
  );
}

function App() {
  const { steps } = useBootstrap();

  return (
    <Box>
      <Box flexDirection="column" borderStyle="round" borderColor="gray" paddingX={2} paddingY={1}>
        <Text bold color="blue">{BANNER}</Text>
        <Box marginTop={1} flexDirection="column">
          <StepList steps={steps} />
        </Box>
      </Box>

      <Box flexDirection="column" borderStyle="round" borderColor="gray" paddingX={2} paddingY={1} flexGrow={1}>
        <ActiveStep />
      </Box>
    </Box>
  );
}

render(
  <BootstrapProvider>
    <App />
  </BootstrapProvider>,
);
