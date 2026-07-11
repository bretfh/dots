;;;; -*- Mode: Lisp; indent-tabs-mode: nil -*-

(in-package :pine.vt)

(defun process-sgr (term params)
  (let ((attrs (term-attrs term))
        (i 0)
        (len (length params)))
    (flet ((next-param ()
             (when (< i len)
               (prog1 (nth i params)
                 (incf i)))))
      (when (zerop len)
        (reset-face-attrs attrs)
        (return-from process-sgr))
      (loop while (< i len) do
        (let ((code (or (next-param) 0)))
          (case code
            (0 (reset-face-attrs attrs))
            (1 (setf (face-bold attrs) t
                     (face-faint attrs) nil))
            (2 (setf (face-faint attrs) t
                     (face-bold attrs) nil))
            (3 (setf (face-italic attrs) t))
            (4
             (let ((sub (when (< i len)
                          (let ((p (nth i params)))
                            (when (and p (listp p))
                              (incf i)
                              (car p))))))
               (if sub
                   (case sub
                     (0 (setf (face-underline attrs) nil))
                     (1 (setf (face-underline attrs) :single))
                     (2 (setf (face-underline attrs) :double))
                     (3 (setf (face-underline attrs) :curly))
                     (4 (setf (face-underline attrs) :dotted))
                     (5 (setf (face-underline attrs) :dashed)))
                   (setf (face-underline attrs) :single))))
            (5 (setf (face-blink attrs) :slow))
            (6 (setf (face-blink attrs) :fast))
            (7 (setf (face-inverse attrs) t))
            (8 (setf (face-conceal attrs) t))
            (9 (setf (face-crossed attrs) t))
            (21 (setf (face-underline attrs) :double))
            (22 (setf (face-bold attrs) nil
                      (face-faint attrs) nil))
            (23 (setf (face-italic attrs) nil))
            (24 (setf (face-underline attrs) nil))
            (25 (setf (face-blink attrs) nil))
            (27 (setf (face-inverse attrs) nil))
            (28 (setf (face-conceal attrs) nil))
            (29 (setf (face-crossed attrs) nil))
            (39 (setf (face-fg attrs) nil))
            (49 (setf (face-bg attrs) nil))
            (59 (setf (face-underline-color attrs) nil))
            (t
             (cond
               ((<= 30 code 37)
                (setf (face-fg attrs) (- code 30)))
               ((<= 40 code 47)
                (setf (face-bg attrs) (- code 40)))
               ((<= 90 code 97)
                (setf (face-fg attrs) (+ 8 (- code 90))))
               ((<= 100 code 107)
                (setf (face-bg attrs) (+ 8 (- code 100))))
               ((= code 38)
                (let ((mode (next-param)))
                  (case mode
                    (5 (let ((c (next-param)))
                         (when (and c (<= 0 c 255))
                           (setf (face-fg attrs) c))))
                    (2 (let ((r (next-param))
                             (g (next-param))
                             (b (next-param)))
                         (when (and r g b
                                    (<= 0 r 255)
                                    (<= 0 g 255)
                                    (<= 0 b 255))
                           (setf (face-fg attrs) (list r g b))))))))
               ((= code 48)
                (let ((mode (next-param)))
                  (case mode
                    (5 (let ((c (next-param)))
                         (when (and c (<= 0 c 255))
                           (setf (face-bg attrs) c))))
                    (2 (let ((r (next-param))
                             (g (next-param))
                             (b (next-param)))
                         (when (and r g b
                                    (<= 0 r 255)
                                    (<= 0 g 255)
                                    (<= 0 b 255))
                           (setf (face-bg attrs) (list r g b))))))))
               ((= code 58)
                (let ((mode (next-param)))
                  (case mode
                    (5 (let ((c (next-param)))
                         (when (and c (<= 0 c 255))
                           (setf (face-underline-color attrs) c))))
                    (2 (let ((r (next-param))
                             (g (next-param))
                             (b (next-param)))
                         (when (and r g b
                                    (<= 0 r 255)
                                    (<= 0 g 255)
                                    (<= 0 b 255))
                           (setf (face-underline-color attrs)
                                 (list r g b))))))))))))))))

(defun reset-face-attrs (attrs)
  (setf (face-fg attrs) nil
        (face-bg attrs) nil
        (face-bold attrs) nil
        (face-faint attrs) nil
        (face-italic attrs) nil
        (face-underline attrs) nil
        (face-underline-color attrs) nil
        (face-blink attrs) nil
        (face-inverse attrs) nil
        (face-conceal attrs) nil
        (face-crossed attrs) nil))
