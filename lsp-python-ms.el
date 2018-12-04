;;; lsp-python-ms.el --- summary -*- lexical-binding: t -*-

;; Author: Charl Botha
;; Maintainer: Andrew Christianson
;; Version: 0.1.0
;; Package-Requires: (lsp-mode cl)
;; Homepage: https://git.sr.ht/~kristjansson/lsp-python-ms
;; Keywords: lsp python


;; This file is not part of GNU Emacs

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.


;;; Commentary:

;; from https://vxlabs.com/2018/11/19/configuring-emacs-lsp-mode-and-microsofts-visual-studio-code-python-language-server/

;;; Code:

(defvar lsp-python-ms-dir nil
  "Path to langeuage server directory containing
Microsoft.Python.LanguageServer.dll")

(defvar lsp-python-ms-dotnet nil
  "Path to dotnet executable.")

;; it's crucial that we send the correct Python version to MS PYLS,
;; else it returns no docs in many cases furthermore, we send the
;; current Python's (can be virtualenv) sys.path as searchPaths

(defun lsp-python-ms--get-python-ver-and-syspath (workspace-root)
  "return list with pyver-string and json-encoded list of python
search paths."
  (let ((python (executable-find python-shell-interpreter))
        (init "from __future__ import print_function; import sys; import json;")
        (ver "print(\"%s.%s\" % (sys.version_info[0], sys.version_info[1]));")
        (sp (concat "sys.path.insert(0, '" workspace-root "'); print(json.dumps(sys.path))")))
    (with-temp-buffer
      (call-process python nil t nil "-c" (concat init ver sp))
      (subseq (split-string (buffer-string) "\n") 0 2))))

;; I based most of this on the vs.code implementation:
;; https://github.com/Microsoft/vscode-python/blob/master/src/client/activation/languageServer/languageServer.ts#L219
;; (it still took quite a while to get right, but here we are!)
(defun lsp-python-ms--extra-init-params (workspace)
  (destructuring-bind (pyver pysyspath)
      (lsp-python-ms--get-python-ver-and-syspath (lsp--workspace-root workspace))
    `(:interpreter
      (:properties (
                    :InterpreterPath ,(executable-find python-shell-interpreter)
                    ;; this database dir will be created if required
                    :DatabasePath ,(expand-file-name (concat lsp-python-ms-dir "db/"))
                    :Version ,pyver))
      ;; preferredFormat "markdown" or "plaintext"
      ;; experiment to find what works best -- over here mostly plaintext
      :displayOptions (
                       :preferredFormat "plaintext"
                       :trimDocumentationLines :json-false
                       :maxDocumentationLineLength 0
                       :trimDocumentationText :json-false
                       :maxDocumentationTextLength 0)
      :searchPaths ,(json-read-from-string pysyspath))))

(defun lsp-python-ms--workspace-root ()
  "Get the root using ffip or projectile, or just return `default-directory'."
  (cond
   ((fboundp 'ffip-get-project-root-directory) (ffip-get-project-root-directory))
   ((fboundp 'projectile-project-root)) (projectile-project-root)
   (t default-directory)))

(defun lsp-python-ms--find-dotnet ()
  "Get the path to dotnet, or return `lsp-python-ms-dotnet'."
  (let ((dotnet (executable-find "dotnet")))
    (if dotnet dotnet lsp-python-ms-dotnet)))

(defun lsp-python-ms--filter-nbsp (str)
  "Filter nbsp entities from STR."
  (replace-regexp-in-string "&nbsp;" " " str))

(setq lsp-render-markdown-markup-content #'lsp-python-ms--filter-nbsp)
(advice-add 'lsp-ui-doc--extract
            :filter-return #'lsp-python-ms--filter-nbsp)

(lsp-define-stdio-client
 lsp-python "python"
 #'lsp-python-ms--workspace-root
 `(,(lsp-python-ms--find-dotnet) ,(concat lsp-python-ms-dir "Microsoft.Python.LanguageServer.dll"))
 :extra-init-params #'lsp-python-ms--extra-init-params)


(provide 'lsp-python-ms)

;;; lsp-python.el ends here
