;;;; base.lisp --- main entry point into nEXT

(defparameter *window* (qnew "QWidget" "windowTitle" "nEXT"))

(defun start ()
  (|show| *window*))

;; start nEXT
(start)

