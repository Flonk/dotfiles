import { createContext, useContext, useState, useCallback, type ReactNode } from "react";
import { STEP_LABELS, type StepInfo, type StepStatus } from "./lib/types.js";
import { parseInstallation } from "./lib/installations.js";
import { execSync } from "child_process";

export type Phase = "running" | "done" | "error";

interface BootstrapContextValue {
  repoRoot: string;

  phase: Phase;
  setPhase: (phase: Phase) => void;

  // Step dispatch (1-indexed). currentStep tracks which Step component renders.
  currentStep: number;
  advanceStep: () => void;
  skipStep: () => void;

  // Installation
  installationName: string;
  setInstallationName: (name: string) => void;
  selectedUser: string;
  setSelectedUser: (user: string) => void;
  selectedHost: string;
  setSelectedHost: (host: string) => void;
  selectedArch: string;
  setSelectedArch: (arch: string) => void;
  isNewHost: boolean;
  setIsNewHost: (v: boolean) => void;
  isNewUser: boolean;
  setIsNewUser: (v: boolean) => void;

  // SSH
  target: string;
  setTarget: (target: string) => void;

  // Age recipients — host set in step 5, user set in step 7
  hostAgeRecipient: string | null;
  setHostAgeRecipient: (key: string) => void;
  userAgeRecipient: string | null;
  setUserAgeRecipient: (key: string) => void;

  // Step status list (0-indexed, parallel to STEP_LABELS)
  steps: StepInfo[];

  // Error / status
  errorMsg: string;
  setErrorMsg: (msg: string) => void;
  statusMsg: string;
  setStatusMsg: (msg: string) => void;

  // Fail handler used by step components on thrown errors
  fail: (msg: string) => void;

  // Derived
  hostFromInstallation: () => string;
}

const BootstrapContext = createContext<BootstrapContextValue | null>(null);

export function useBootstrap(): BootstrapContextValue {
  const ctx = useContext(BootstrapContext);
  if (!ctx) throw new Error("useBootstrap must be used within BootstrapProvider");
  return ctx;
}

function getRepoRoot(): string {
  return execSync("git rev-parse --show-toplevel", { encoding: "utf-8" }).trim();
}

export function BootstrapProvider({ children }: { children: ReactNode }) {
  const repoRoot = getRepoRoot();

  const [phase, setPhase] = useState<Phase>("running");
  const [currentStep, setCurrentStep] = useState(1);
  const [installationName, setInstallationName] = useState("");
  const [selectedUser, setSelectedUser] = useState("");
  const [selectedHost, setSelectedHost] = useState("");
  const [selectedArch, setSelectedArch] = useState("x86_64-linux");
  const [isNewHost, setIsNewHost] = useState(false);
  const [isNewUser, setIsNewUser] = useState(false);
  const [target, setTarget] = useState("");
  const [hostAgeRecipient, setHostAgeRecipient] = useState<string | null>(null);
  const [userAgeRecipient, setUserAgeRecipient] = useState<string | null>(null);
  const [errorMsg, setErrorMsg] = useState("");
  const [statusMsg, setStatusMsg] = useState("");
  const [steps, setSteps] = useState<StepInfo[]>(
    STEP_LABELS.map((label, i) => ({ label, status: (i === 0 ? "running" : "pending") as StepStatus })),
  );

  const finishCurrent = useCallback(
    (finalStatus: StepStatus) => {
      setSteps((prev) => {
        const next = [...prev];
        const idx = currentStep - 1;
        if (idx >= 0 && idx < next.length) next[idx] = { ...next[idx], status: finalStatus };
        const nextIdx = idx + 1;
        if (nextIdx < next.length) next[nextIdx] = { ...next[nextIdx], status: "running" };
        return next;
      });
      setCurrentStep((s) => s + 1);
    },
    [currentStep],
  );

  const advanceStep = useCallback(() => finishCurrent("done"), [finishCurrent]);
  const skipStep = useCallback(() => finishCurrent("skipped"), [finishCurrent]);

  const fail = useCallback((msg: string) => {
    setErrorMsg(msg);
    setSteps((prev) =>
      prev.map((s) => (s.status === "running" ? { ...s, status: "error" as StepStatus } : s)),
    );
    setPhase("error");
  }, []);

  const hostFromInstallation = useCallback(() => {
    if (selectedHost) return selectedHost;
    return parseInstallation(repoRoot, installationName).host;
  }, [selectedHost, installationName, repoRoot]);

  return (
    <BootstrapContext.Provider
      value={{
        repoRoot,
        phase,
        setPhase,
        currentStep,
        advanceStep,
        skipStep,
        installationName,
        setInstallationName,
        selectedUser,
        setSelectedUser,
        selectedHost,
        setSelectedHost,
        selectedArch,
        setSelectedArch,
        isNewHost,
        setIsNewHost,
        isNewUser,
        setIsNewUser,
        target,
        setTarget,
        hostAgeRecipient,
        setHostAgeRecipient,
        userAgeRecipient,
        setUserAgeRecipient,
        steps,
        errorMsg,
        setErrorMsg,
        statusMsg,
        setStatusMsg,
        fail,
        hostFromInstallation,
      }}
    >
      {children}
    </BootstrapContext.Provider>
  );
}
