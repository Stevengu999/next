;;;; base.lisp --- main entry point into nEXT

(in-package :next)

;; (qrequire :webkit)


(defparameter *window* (qnew "QWidget" "windowTitle" "nEXT"))
(defparameter *root-layout* (qnew "QGridLayout"))
(defparameter *stack-layout* (qnew "QStackedLayout"))

(setf *minibuffer* (generate-new-buffer "minibuffer" (minibuffer-mode) nil))
;; (setf *active-buffer* (generate-new-buffer "default" (document-mode)))
(setf *active-buffer* (setf *history-tree* (generate-new-buffer "history-tree" (tree-history-mode))))

;; Used by QT to capture key presses
(qadd-event-filter nil |QEvent.KeyPress| 'key-press)
(qadd-event-filter nil |QEvent.KeyRelease| 'key-release)

(defun start ()
  ;; remove margins around root widgets
  (|setSpacing| *root-layout* 0)
  (|setContentsMargins| *root-layout* 0 0 0 0)
   ;; arguments for grid layout: row, column, rowspan, colspan
  (|addLayout| *root-layout* *stack-layout*              0 0 1 1)
  (|addWidget| *root-layout* (buffer-view *minibuffer*)  1 0 1 1)
  
  (|hide| (buffer-view *minibuffer*))
  (|setLayout| *window* *root-layout*)
  (|show| *window*))

;; start nEXT
(start)

;; load the user configuration if it exists
(load "~/.next.d/init.lisp" :if-does-not-exist nil)

(defvar *lib* (qnew "QLibrary"))

(defun try-load ()
  (let ((local (|getText.QInputDialog| nil "" "Please enter the local path to eql5_webkit,<br>e.g. \"../libs\"")))
    (when (x:empty-string local)
      (return-from try-load t))
    (|setFileName| *lib* (format nil "~A/~A/eql5_webkit"
                                 (|applicationDirPath.QCoreApplication|)
                                 (string-trim "/" local)))
    (x:d (|fileName| *lib*))
    (when (|load| *lib*)
      (qmsg (format nil "Success! The path is:~%~%~A" (|fileName| *lib*)))
      t)))

(defun try-load-loop ()
  (loop (when (try-load)
	  (return))))


(define-key global-map (kbd "C-y") #'try-load-loop)
