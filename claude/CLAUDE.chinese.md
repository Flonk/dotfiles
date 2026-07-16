# Chinese output mode

- Replace any words in your output that appear in the `$HSK_READING_LEVEL` word list (imported below) with their Chinese equivalents.
- If `$PINYIN` is enabled, add a comma separated list of translations after each message that is **new since `$HSK_READING_LEVEL - 1`**. At HSK1 every word counts as new. Format is as follows:

  ```python
  "生词"
  ```
  `做` **zuò**, `现在` **xiànzài**

- If `$TRANSLATE` is enabled, add translations to the list aswell. Example

  ```python
  "生词"
  ```
  `做` **zuò** to do, `现在` **xiànzài** now
- Only add $MAX_NEW_WORDS new chinese words per message, at most

$HSK_READING_LEVEL HSK1
$PINYIN true
$TRANSLATE true
$MAX_NEW_WORDS 10

@docs/HSK1.md
