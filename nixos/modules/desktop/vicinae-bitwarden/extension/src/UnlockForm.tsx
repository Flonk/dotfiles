import { useState } from "react";
import { Action, ActionPanel, Form, showToast, Toast } from "@vicinae/api";
import { VaultItem, unlock } from "./rbw";

export function UnlockForm({
  onUnlock,
}: {
  onUnlock: (items: VaultItem[], masterPassword: string) => void;
}) {
  const [error, setError] = useState<string>();

  const handleSubmit = async (values: Form.Values) => {
    const masterPassword = values.password as string;
    const toast = await showToast({
      style: Toast.Style.Animated,
      title: "Unlocking vault…",
    });
    try {
      const items = await unlock(masterPassword);
      toast.style = Toast.Style.Success;
      toast.title = "Vault unlocked";
      await toast.update();
      onUnlock(items, masterPassword);
    } catch {
      toast.style = Toast.Style.Failure;
      toast.title = "Incorrect master password";
      await toast.update();
      setError("Incorrect master password");
    }
  };

  return (
    <Form
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Unlock" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.PasswordField
        id="password"
        title="Master Password"
        autoFocus
        error={error}
        onChange={() => {
          if (error) setError(undefined);
        }}
      />
    </Form>
  );
}
