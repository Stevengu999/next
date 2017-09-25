;;;; base.lisp --- main entry point into nEXT

(in-package :next)

(defparameter *window* (qnew "QWidget" "windowTitle" "nEXT"))

(defun start ()
  (|show| *window*))

;; start nEXT
(start)

