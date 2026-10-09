/// <reference types="@vicinae/api">

/*
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 */

type ExtensionPreferences = {
  
}

declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Command: Ask For Password */
	export type Ask = ExtensionPreferences & {
		
	}
}

declare namespace Arguments {
  /** Command: Ask For Password */
	export type Ask = {
		/** Prompt */
		"prompt": string

		/** Channel */
		"channel": string
	}
}