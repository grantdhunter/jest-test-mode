;;; jest-test-mode.el --- Minor mode for running Node.js tests using jest

;; Author: Raymond Huang <rymndhng@gmail.com>
;; URL: https://github.com/rymndhng/jest.el
;; Version: 0.1
;;

;;; Commentary:

;; This mode provides commands for running node tests using jest. The output is
;; shown in a separate buffer '*compilation*' in compilation mode. Backtraces
;; from failures and errors are marked and can be clicked to bring up the
;; relevent source file, where point is moved to the named line.
;;
;; The tests should be written with jest. File names are supposed to end in `.test.ts'
;;
;; Using the command `jest-test-run-at-point`, you can run test cases from the
;; current file.

;; Keybindings:
;;
;; C-c C-t n    - Runs the current buffer's file as an unit test or an rspec example.
;; C-c C-t p    - Runs all tests in the project
;; C-C C-t t    - Runs describe block at point
;; C-C C-t a    - Re-runs the last test command

(defgroup jest-test nil
  "Minor mode providing commands for running jest tests in Node.js"
  :group 'js)

(defcustom jest-test-options
  '("--color")
  "Pass extra comand line options to jest when running specs"
  :initialize 'custom-initialize-default
  :type '(list)
  :group 'jest-test-mode)

(defvar jest-test-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-t n")   'jest-test-run)
    (define-key map (kbd "C-c C-t p")   'jest-test-run-all-tests)
    (define-key map (kbd "C-c C-t a")   'jest-test-rerun-test)
    (define-key map (kbd "C-c C-t t")   'jest-test-run-at-point)
    ;; (define-key map (kbd "C-c C-s")     'jest-test-toggle-implementation-and-test)
    map)
  "The keymap used in command `jest-test-mode' buffers.")

(define-minor-mode jest-test-mode
  "Toggle jest minor mode.
With no argument, this command toggles the mode. Non-null prefix
argument turns on the mode. Null prefix argument turns off the
mode"
  :init-value nil
  :lighter " Jest"
  :keymap 'jest-test-mode-map
  :group 'jest-test-mode)

(defmacro jest-test-from-project-directory (filename form)
  "Set to npm project root inferred from FILENAME and run the provided FROM with `default-directory` bound.g"
  (declare (indent 1))
  `(let ((default-directory (or (jest-test-project-root ,filename)
                                default-directory)))
     ,form))

(defun jest-test-project-root (filename)
  (if (jest-test-npm-project-root-p filename)
      filename
    (and filename
         (not (string= "/" filename))
         (jest-test-project-root
          (file-name-directory
           (directory-file-name (file-name-directory filename)))))))

(defun jest-test-npm-project-root-p (directory)
  (file-exists-p (concat (file-name-as-directory directory) "/package.json")))

(defun jest-test-find-file ()
  "Finds the testfile to run. Assumed to be the current file."
  (buffer-file-name))

(defvar jest-test-not-found-message "No test among visible bufers")

;;;###autoload
(defun jest-test-run ()
  "Runs the current buffer's file as a test"
  (interactive)
  (let ((filename (jest-test-find-file)))
    (if filename
        (jest-test-from-project-directory filename
          (jest-test-run-command (jest-test-command filename)))
      (message jest-test-not-found-message))))

(defun jest-test-run-all-tests ()
  "Runs all tests in the project"
  (interactive)
  (jest-test-from-project-directory (buffer-file-name)
    (jest-test-run-command (jest-test-command ""))))

(defun jest-test-rerun-test ()
  "Runs the previously run test in the project"
  (interactive)
  (jest-test-from-project-directory (buffer-file-name)
    (jest-test-run-command jest-test-last-test-command)))

(defun jest-test-run-at-point ()
  "Runs the top level describe block of the current buffer's point"
  (interactive)
  (let ((filename (jest-test-find-file))
        (example  (jest-test-example-at-point)))
    (if (and filename example)
        (jest-test-from-project-directory filename
          (let ((jest-test-options (seq-concatenate 'list jest-test-options (list "-t" example))))
            (jest-test-run-command (jest-test-command filename))))
      (message jest-test-not-found-message))))

(defun jest-test-example-at-point ()
  "Finds the topmost describe block from where the cursor is and extract the name"
  (save-excursion
    (re-search-backward "^describe")
    (let ((text (thing-at-point 'line t)))
      (string-match "describe\(\\(.*\\)," text)
      (when-let ((example (match-string 1 text)))
        (substring example 1 -1)))))

(defvar jest-test-last-test-command
  "The last test command ran with.")

(defun jest-test-update-last-test (command)
  "Updates the last test command"
  (setq jest-test-last-test-command command))

(defun jest-test-run-command (command)
  "Runs compilation COMMAND in NPM project root."
  (jest-test-update-last-test command)
  (compilation-start command t))

;;;###autoload
(defun jest-test-command (filename)
  (let ((command "npx jest")
        (options jest-test-options))
    (format "%s %s %s" command (mapconcat 'shell-quote-argument options " ") filename)))

;;; compilation-mode support

;; Source: https://emacs.stackexchange.com/questions/27213/how-can-i-add-a-compilation-error-regex-for-node-js
;; Handle errors that match this:
;; at addSpecsToSuite (node_modules/jest-jasmine2/build/jasmine/Env.js:522:17)
(add-to-list 'compilation-error-regexp-alist 'jest)
(add-to-list 'compilation-error-regexp-alist-alist
             '(jest "at [^ ]+ (\\(.+?\\):\\([[:digit:]]+\\):\\([[:digit:]]+\\)" 1 2 3))

(defun jest-test-enable ()
  "Enable the jest test mode."
  (jest-test-mode 1))

(add-hook 'typescript-mode-hook 'jest-test-enable)
(add-hook 'js-mode-hook 'jest-test-enable)

(provide 'jest-test-mode)
;;; jest-test-mode.el ends here