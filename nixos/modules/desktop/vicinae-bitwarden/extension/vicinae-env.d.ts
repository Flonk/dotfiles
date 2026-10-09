/// <reference types="@vicinae/api">

/*
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 */

type ExtensionPreferences = {
  
}

declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Command: Search Vault */
	export type Search = ExtensionPreferences & {
		
	}
}

declare namespace Arguments {
  /** Command: Search Vault */
	export type Search = {
		/** Search query */
		"query": string
	}
}