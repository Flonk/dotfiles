import { useState } from "react";
import {
  Action,
  ActionPanel,
  Detail,
  Form,
  LaunchProps,
  closeMainWindow,
} from "@vicinae/api";
import { writeFileSync } from "fs";

export default function Ask(
  props: LaunchProps<{ arguments: { prompt: string; channel: string } }>,
) {
  const { prompt, channel } = props.arguments;
  const [error, setError] = useState<string>();

  if (!channel) {
    return (
      <Detail markdown="**Askpass**\n\nThis command is launched by the `vicinae-askpass` wrapper when a program asks for a password. There is nothing to do here." />
    );
  }

  const handleSubmit = async (values: Form.Values) => {
    try {
      writeFileSync(channel, `${values.password as string}\n`);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
      return;
    }
    await closeMainWindow();
  };

  return (
    <Form
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Submit" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.PasswordField
        id="password"
        title={prompt || "Password"}
        autoFocus
        error={error}
        onChange={() => {
          if (error) setError(undefined);
        }}
      />
    </Form>
  );
}
