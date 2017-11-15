;;;; cocoa.lisp --- cocoa helper functions & data

(in-package :interface)

(defparameter *window* nil)
(defparameter *next-view* nil)

(defclass minibuffer-view (ns:ns-view)
  ((input-buffer :accessor input-buffer)
   (completion-table :accessor completion-table)
   (completion-controller :accessor completion-controller)
   (completion-function :accessor completion-function))
    (:metaclass ns:+ns-object))

(defmethod initialize-instance :after ((self minibuffer-view)
				       &key &allow-other-keys)
  (let* ((input-field (make-instance 'ns:ns-text-field
				     :delegate self))
	 (completion-controller (make-instance 'controller
					      :data ()))
	 (completion-column (#/autorelease (make-instance ns:ns-table-column
							  :column-title "Completion"
							  :identifier "Completion"
							  :min-width 80
							  :editable nil
							  :selectable t)))
	 (completion-table
	  (make-instance ns:ns-table-view
                    :columns (list completion-column)
                    :data-source completion-controller
                    :delegate completion-controller
                    :allows-column-resizing nil
                    :column-autoresizing-style :uniform)))
    (setf (input-buffer self) input-field)
    (setf (completion-table self) completion-table)
    (setf (completion-controller self) completion-controller)
    (setf (view completion-controller) completion-table)
    (#/addSubview: self input-field)
    (#/addSubview: self completion-table)
    (make-constraint :item1 input-field :att1 :center-x :relation := :item2 self :att2 :center-x)
    (make-constraint :item1 input-field :att1 :width :relation := :item2 self :att2 :width)
    (make-constraint :item1 input-field :att1 :top :relation := :item2 self :att2 :top)
    (make-constraint :item1 input-field :att1 :height :relation := :const 20)
    (make-constraint :item1 completion-table :att1 :top :relation := :item2 input-field :att2 :bottom)
    (make-constraint :item1 completion-table :att1 :bottom :relation := :item2 self :att2 :bottom)
    (make-constraint :item1 completion-table :att1 :width :relation := :item2 self :att2 :width)))

(defmethod get-input ((self minibuffer-view))
  (ns-to-lisp-string (#/stringValue (input-buffer self))))

(defmethod process-set-completions ((self minibuffer-view))
  "Process and set completions for the minibuffer"
  (with-slots (completion-function completion-controller completion-table) self
    (when (completion-function self)
      (setf (data completion-controller) (funcall completion-function (get-input self)))
      (#/reloadData completion-table))))

(objc:defmethod (#/controlTextDidChange: :void) ((self minibuffer-view) notification)
  (declare (ignore notification))
  (process-set-completions self))

(defclass next-web-view (ns:web-view)
  ((load-finished-call-back :accessor load-finished-call-back))
  (:metaclass ns:+ns-object))

(objc:defmethod (#/webView:didFinishLoadForFrame: :void)
    ((self next-web-view)
     (wvs :id)
     (fl :id))
  (declare (ignore wvs fl))
  (funcall (load-finished-call-back self)))

(defclass fill-container-view (ns:ns-view)
  ((fill-view :accessor fill-view
		    :initarg :fill-view))
  (:default-initargs
   :fill-view nil)
  (:metaclass ns:+ns-object))

(defmethod initialize-instance :after ((self fill-container-view)
                                       &key (fill-view nil) &allow-other-keys)
  (when (and fill-view (view-p fill-view))
    (#/addSubview: self fill-view)
    (constrain-size-relative-to fill-view self :rel :=)))

(defmethod set-fill-view ((self fill-container-view) view)
  (on-main-thread
   (when (fill-view self)
     (#/removeFromSuperview (fill-view self)))
   (#/addSubview: self view)
   (constrain-size-relative-to view self :rel :=))
  (setf (fill-view self) view))

(defclass next-view (ns:ns-view)
  ((%fill-container-view :accessor fill-container-view)
   (%minibuffer-view :accessor minibuffer-view)
   (minibuffer-height-constraint :accessor minibuffer-height-constraint))
  (:metaclass ns:+ns-object))

(defmethod initialize-instance :after ((self next-view)
				       &key &allow-other-keys)
  (let ((fvc (make-instance 'fill-container-view))
	(mb (make-instance 'minibuffer-view)))
    (#/addSubview: self fvc)
    (#/addSubview: self mb)
    (setf (fill-container-view self) fvc)
    (setf (minibuffer-view self) mb)
    (make-constraint :item1 fvc :att1 :top :relation := :item2 self :att2 :top)
    (make-constraint :item1 fvc :att1 :width :relation := :item2 self :att2 :width)
    (make-constraint :item1 fvc :att1 :bottom :relation := :item2 mb :att2 :top)
    (make-constraint :item1 mb :att1 :bottom :relation := :item2 self :att2 :bottom)
    (make-constraint :item1 mb :att1 :width :relation := :item2 self :att2 :width)
    (setf (minibuffer-height-constraint self)
	  (make-constraint :item1 mb :att1 :height :relation := :const 0))))

(defmethod hide-minibuffer ((self next-view))
  (on-main-thread
   (#/setConstant: (minibuffer-height-constraint self) 0)))

(defmethod show-minibuffer ((self next-view))
  (on-main-thread
   (#/setConstant: (minibuffer-height-constraint self) 200)))

(defclass next-window (ns:ns-window) ()
  (:metaclass ns:+ns-object))

(objc:defmethod (#/acceptsFirstResponder :<BOOL>) ((self next-window)) t)

(objc:defmethod (#/keyDown: :void) ((self next-window) event)
  (let* ((flags (#/modifierFlags event))
	 (character (ns-to-lisp-string (#/charactersIgnoringModifiers event))))
    (next:push-key-chord
     (> (logand flags #$NSControlKeyMask) 0)
     (> (logand flags #$NSAlternateKeyMask) 0)
     (> (logand flags #$NSCommandKeyMask) 0)
     character)
    (call-next-method event)))

(defun process-event (event)
  (let* ((flags (#/modifierFlags event))
	 (character (ns-to-lisp-string (#/charactersIgnoringModifiers event))))
    (next:push-key-chord
     (> (logand flags #$NSControlKeyMask) 0)
     (> (logand flags #$NSAlternateKeyMask) 0)
     (> (logand flags #$NSCommandKeyMask) 0)
     character)))

(defun make-window ()
  (gui::assume-cocoa-thread)
  (ns:with-ns-rect (r 100.0 100.0 1024.0 768.0)
    (ccl::with-autorelease-pool 
      (let* ((.window. (make-instance
		      'next-window
		      :with-content-rect r
		      :style-mask (logior #$NSTitledWindowMask
					  #$NSClosableWindowMask
					  #$NSMiniaturizableWindowMask
					  #$NSResizableWindowMask)
		      :backing #$NSBackingStoreBuffered
		      :title "nEXT"
		      :defer t))
	     (.next-view. (make-instance 'next-view)))
	(#/setContentView: .window. .next-view.)
	(#/makeKeyAndOrderFront: .window. +null-ptr+)
	(setf *window* .window.)
	(setf *next-view* .next-view.)
	*window*))))

(defun initialize ())

(defun start ()
  (on-main-thread
   (make-window)))

(defun kill ()
  (quit))

(defun set-visible-view (view)
  (set-fill-view (fill-container-view *next-view*) view))

(defun make-web-view ()
  (on-main-thread
   (let ((view (make-instance
		'next-web-view
		:frame-name #@"frame"
		:group-name #@"group")))
     (#/setFrameLoadDelegate: view view)
     view)))

(defun url-from-string (s)
  (ccl::with-autorelease-pool
    (#/retain (#/URLWithString: ns:ns-url (ccl::%make-nsstring (string s))))))

(defun web-view-set-url (view url)
  (on-main-thread
   (let* ((nsurl (url-from-string url))
	  (webframe (#/mainFrame view))
	  (request (#/requestWithURL: ns:ns-url-request nsurl)))
     (#/loadRequest: webframe request))))

(defun delete-view (view)
  view)

(defun web-view-scroll-down (view)
  (on-main-thread
   (#/stringByEvaluatingJavaScriptFromString: view #@"window.scrollBy(0, 100);")))

(defun web-view-scroll-up (view)
  (on-main-thread
   (#/stringByEvaluatingJavaScriptFromString: view #@"window.scrollBy(0, -100);")))

(defun web-view-set-url-loaded-callback (view function)
  (setf (load-finished-call-back view) function))

(defun web-view-get-url (view)
  (ns-to-lisp-string (#/mainFrameURL view)))

(defun make-minibuffer ()
  (minibuffer-view *next-view*))

(defun minibuffer-show ()
  (show-minibuffer *next-view*)
  (#/makeFirstResponder: *window* (input-buffer (minibuffer-view *next-view*)))
  (process-set-completions (minibuffer-view *next-view*)))

(defun minibuffer-hide ()
  (hide-minibuffer *next-view*)
  (#/makeFirstResponder: *window* (fill-container-view *next-view*)))

(defun minibuffer-get-input ()
  (get-input (minibuffer-view *next-view*)))

(defun minibuffer-set-completion-function (function)
  (setf (completion-function (minibuffer-view *next-view*)) function))