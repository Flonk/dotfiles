export type StepStatus = "pending" | "running" | "done" | "error" | "skipped";

export interface StepInfo {
  label: string;
  status: StepStatus;
}

export interface Installation {
  name: string; // e.g. "flo-chonkler"
  user: string; // e.g. "flo"
  host: string; // e.g. "chonkler"
  isNew: boolean;
}

export const REPO_OWNER = "Flonk";
export const REPO_NAME = "dotfiles";
export function remoteRepoPath(user: string): string {
  return `/home/${user}/repos/personal/dotfiles`;
}
export const GIT_CLONE_URL = `https://github.com/${REPO_OWNER}/${REPO_NAME}.git`;

export const STEP_LABELS = [
  "Select installation",
  "Connect via SSH",
  "Check for NixOS",
  "Add config to repo",
  "Install Skynet",
  "Create User",
] as const;
