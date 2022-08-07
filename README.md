# emacs-markdown-babel

package to bring some org-babel conveniences into markdown editing in Emacs

if you miss C-c C-c of org-babel code blocks when editing md files, this is for you

currently has rudimentary support for `emacs-lisp`, `sh`, `clojure` (by shelling to [babashka](https://github.com/babashka/babashka)), and `python` (via jupyter session, using [emacs-jupyter](https://github.com/nnicandro/emacs-jupyter)

# usage

create code blocks using markdown fenced code syntax, with the language code right after the fence, like [github flavored markdown's info string, example 112](https://github.github.com/gfm/#example-112).

within the code block, evaluate `markdown-eval-current-code-block`.

## sh

```sh
echo "hello friendly geometer"
emacs --version | head -1
```
```
hello friendly geometer
GNU Emacs 27.2
```

## emacs-lisp

```emacs-lisp
(format "%s %s" "enjoy a parenthetical message from" (buffer-name))
```
```
enjoy a parenthetical message from README.md<emacs-markdown-babel>
```

## clojure

clojure via babashka. This means you can also use pods:

```clojure
(require '[babashka.pods :as pods])
(pods/load-pod 'retrogradeorbit/bootleg "0.1.9")
(require '[pod.retrogradeorbit.bootleg.utils :as utils])
(println (let [hiccup [:div {:style {:border "1px solid blue"}} [:h1 "babashka you a great happiness"]]] (utils/convert-to hiccup :html)))
```
```
<div style="border:1px solid blue;"><h1>babashka you a great happiness</h1></div>
```

## jupyter

this is ~~jank~~ a lot trickier. but the basic steps are as follows:

1. make sure you have installed [emacs-jupyter](https://github.com/nnicandro/emacs-jupyter) and are able to get it to work with org-mode first
2. start a jupyter notebook server somewhere and an active kernel
3. find the **absolute** path to the active kernel's json file
   - you can use e.g. `jupyter --runtime-dir` to discover where jupyter stores its runtime files
   - the runtime dir may also be stored in the `JUPYTER_RUNTIME_DIR` environment variable
   - you can also refer to the server messages in the terminal, which look like e.g. `[I 10:56:07.788 NotebookApp] Kernel started: 34a75604-d249-436c-b7ca-769709d8ff8e, name: python3`; the UUID here gives you a hint
   - your kernel file will be in the form of `<UUID>.json`
   - if you don't have a lot of kernel activity you can probably do `ls -1rt $JUPYTER_RUNTIME_DIR/*.json`
4. create a source block, in the same way you would for `jupyter-python` in org-mode, with the absolute path to the json kernel file as the `:session` parameter. See the raw source of this readme file for an example.

```jupyter-python :session /usr/local/cache/jupyter-notebook-sandbox-with-extensions-jupyter-work/runtime/kernel-34a75604-d249-436c-b7ca-769709d8ff8e.json :results output
import sys
print(sys.version)
```
```
3.8.12 (default, Aug 30 2021, 16:42:10)
[GCC 10.3.0]
```
