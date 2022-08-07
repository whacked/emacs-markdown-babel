;; version
;; 0.0.1-alpha

;; status
;; "works for me"

;; depends:
;; - markdown-mode (https://github.com/jrblevin/markdown-mode)
;; - s (https://github.com/magnars/s.el)
;; - f (https://github.com/rejeep/f.el)

(defun markdown-insert-fenced-block (content)
  (insert
   (format "```\n%s\n```\n"
           (s-trim-right content))))

(defun markdown-parse-block-directive (directive)
  (let* ((split-directive (s-split-up-to "\s+" directive 1))
         (language (car split-directive))
         (language-block-string (cadr split-directive)))
    (org-babel-parse-header-arguments
     ;; ugly
     (concat ":language " language " " language-block-string))))

(save-excursion
  (buffer-substring (line-beginning-position) (line-end-position)))

(defun markdown-eval-current-code-block ()
  (interactive)

  (let ((code-block-position (markdown-code-block-at-pos (point))))
    (if (not code-block-position)
        (message "not in a code block")
      (let* ((beg (car code-block-position))
             (end (cadr code-block-position))
             (code-block-body
              (buffer-substring
               (save-excursion
                 (goto-char beg)
                 (forward-line)
                 (point))
               (- end 4)))
             (code-block-header
              (save-excursion
                (markdown-beginning-of-text-block)
                (forward-char 1) ;; it may move to the line above the fence
                (s-trim-right (substring (thing-at-point 'line t) 3))))
             (directive-alist (markdown-parse-block-directive code-block-header))
             (language (cdr (assq :language directive-alist))))

        (message
         "lang: %s\nhead: %s\nbody: %s"
         language code-block-header code-block-body)

        (save-excursion
          (markdown-end-of-text-block)
          (when (not (= 0 (current-column))) ;; special case where the final char of the buffer is the end of the code fence
            (insert "\n"))

          (cond ((string= language "emacs-lisp")
                 (markdown-insert-fenced-block
                  (eval (car (read-from-string code-block-body)))))

                ((string= language "sh")
                 (markdown-insert-fenced-block
                  (org-babel-sh-evaluate
                   nil ;; session
                   code-block-body
                   ;; params
                   '((:colname-names)
                     (:rowname-names)
                     (:result-params . ("replace" "output"))
                     (:result-type . "output")
                     (:exports . code)
                     (:session . none)
                     (:cache . no)
                     (:noweb . no)
                     (:hlines . no)
                     (:tangle . no)))))

                ((string= language "clojure")
                 (markdown-insert-fenced-block
                  (let ((temp-file (make-temp-file "babashka-temp" nil ".clj"))
                        (command "bb"))
                    (f-write-text code-block-body 'utf-8 temp-file)
                    (let ((result
                           (with-temp-buffer
                             (list (call-process command nil t nil temp-file) ;; exit code
                              (buffer-string)))))
                      (if (= 0 (car result))
                          (delete-file temp-file)
                        (message
                         "[execution error] temp file saved to %s" temp-file))
                      (cadr result)))))

                ((string= language "jupyter-python")
                 (let* ((body code-block-body)
                        (async-p nil)
                        (params (append
                                 '((:colname-names)
                                   (:rowname-names)
                                   (:result-params . ("replace" "output"))
                                   (:result-type . "output")
                                   (:exports . code)
                                   (:cache . no)
                                   (:noweb . no)
                                   (:hlines . no)
                                   (:tangle . no)
                                   (:kernel . "python3")
                                   ;; example:
                                   ;; (:session . "/path/to/jupyter/work/runtime/kernel-34a75604-d249-436c-b7ca-769709d8ff8e.json")
                                   (:async . no))
                                 directive-alist))
                        (org-babel-jupyter-current-src-block-params params)
                        (session (alist-get :session params))
                        (buf (org-babel-jupyter-initiate-session session params))
                        (jupyter-current-client (buffer-local-value 'jupyter-current-client buf))
                        (lang (jupyter-kernel-language jupyter-current-client))
                        (vars (org-babel-variable-assignments:jupyter params lang))
                        (code (progn
                                (when-let* ((dir (alist-get :dir params)))
                                  ;; `default-directory' is already set according
                                  ;; to :dir when executing a source block.  Set
                                  ;; :dir to the absolute path so that
                                  ;; `org-babel-expand-body:jupyter' does not try
                                  ;; to re-expand the path. See #302.
                                  (setf (alist-get :dir params) default-directory))
                                (org-babel-expand-body:jupyter body params vars lang))))

                   (let ((jupyter-inhibit-handlers '(not :input-request))
                         (req (jupyter-send-execute-request jupyter-current-client
                                :code code :store-history nil)))

                     ;; see jupyter-eval-add-callbacks()
                     (let* ((eval-callbacks (jupyter-eval-result-callbacks req nil nil)))
                       (apply
                        #'jupyter-add-callback req
                        (nconc
                         eval-callbacks
                         (list
                          :error
                          (jupyter-message-lambda (traceback)
                            ;; FIXME: Assumes the error in the execute-reply is good enough
                            (when (> (apply #'+ (mapcar #'length traceback)) 250)
                              (jupyter-display-traceback traceback)))
                          :stream ;; this is what actually signals to capture the output string!
                          (jupyter-message-lambda (name text)
                            (forward-paragraph)
                            (markdown-insert-fenced-block text)))))
                       req))))

                (t (progn
                     (message "cannot process")))))))))

;; markdown-mode.el also uses C-c C-c as a magic key;
;; F5 comes from a vs code style eval key
(comment
 (eval-after-load 'markdown '(define-key markdown-mode-map [(f5)] 'markdown-eval-current-code-block)))
