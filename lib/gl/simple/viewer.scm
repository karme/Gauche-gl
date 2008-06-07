;;;
;;; simple/viewer.scm - simple viewer
;;;  
;;;   Copyright (c) 2008  Shiro Kawai  <shiro@acm.org>
;;;   
;;;   Redistribution and use in source and binary forms, with or without
;;;   modification, are permitted provided that the following conditions
;;;   are met:
;;;   
;;;   1. Redistributions of source code must retain the above copyright
;;;      notice, this list of conditions and the following disclaimer.
;;;  
;;;   2. Redistributions in binary form must reproduce the above copyright
;;;      notice, this list of conditions and the following disclaimer in the
;;;      documentation and/or other materials provided with the distribution.
;;;  
;;;   3. Neither the name of the authors nor the names of its contributors
;;;      may be used to endorse or promote products derived from this
;;;      software without specific prior written permission.
;;;  
;;;   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;;;   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;;;   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;;;   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;;;   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;;;   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
;;;   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;;;   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;;;   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;;   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;;   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;;  

;; This is a simple viewer skeleton.  It is by no means intended for
;; general applications; it's rather a handy tool to quickly hack up
;; a throwaway script to visualize some data.
;;
;; Since it relies on GLUT, it can only have one global GL context---
;; you can't display more than one window.  

(define-module gl.simple.viewer
  (use gl)
  (use gl.glut)
  (use gl.math3d)
  (use srfi-42)
  (export simple-viewer-window
          simple-viewer-display
          simple-viewer-reshape
          simple-viewer-grid
          simple-viewer-axis
          simple-viewer-set-key!
          simple-viewer-run
          )
  )
(select-module gl.simple.viewer)

;; private globals
(define *key-handlers* (make-hash-table 'eqv?))
(define *display-proc* #f)
(define *grid-proc*    (lambda () (default-grid)))
(define *axis-proc*    (lambda () (default-axis)))
(define *reshape-proc* (lambda (w h) (default-reshape w h)))

;; Set/get handler funcs.  we don't use parameters, since those handler
;; procedures should be shared among threads.
(define-syntax define-access-fn
  (syntax-rules ()
    [(_ name var)
     (define (name . maybe-arg)
       (if (null? maybe-arg)
         var
         (set! var (car maybe-arg))))]))

(define-access-fn simple-viewer-display *display-proc*)
(define-access-fn simple-viewer-reshape *reshape-proc*)
(define-access-fn simple-viewer-grid    *grid-proc*)
(define-access-fn simple-viewer-axis    *axis-proc*)

(define (simple-viewer-set-key! key proc)
  (if proc
    (hash-table-put! *key-handlers* key proc)
    (hash-table-delete! *key-handlers* key)))

(define (simple-viewer-window . keys)
  (let-keywords keys ((mode (logior GLUT_DOUBLE GLUT_DEPTH GLUT_RGB))
                      (title "gl.simple.viewer")
                      (width  300)
                      (height 300))
    (glut-init-display-mode (logior GLUT_DOUBLE GLUT_DEPTH GLUT_RGB))
    (glut-init-window-size     600 600)
    (glut-create-window title)

    ;; enable some commonly used stuff
    (gl-enable GL_CULL_FACE)
    (gl-enable GL_DEPTH_TEST)
    (gl-enable GL_NORMALIZE)
    ))

(define (simple-viewer-run . keys)
  (let-keywords keys ((rescue-errors #t)
                      )
    (let ((prev-x -1)
          (prev-y -1)
          (prev-b #f)
          (vp-width 300)
          (vp-height 300)
          (rotx 20.0)
          (roty -30.0)
          (rotz 0.0)
          (xlatx 0.0)
          (xlaty 0.0)
          (zoom  1.0)
          (initialized #f))

      (define (display-fn)
        (gl-clear (logior GL_COLOR_BUFFER_BIT GL_DEPTH_BUFFER_BIT))
        (gl-push-matrix)
        (gl-scale zoom zoom zoom)
        (gl-translate xlatx xlaty 0.0)
        (gl-rotate rotx 1.0 0.0 0.0)
        (gl-rotate roty 0.0 1.0 0.0)
        (gl-rotate rotz 0.0 0.0 1.0)

        (gl-disable GL_LIGHTING)
        (and *grid-proc* (*grid-proc*))
        (and *axis-proc* (*axis-proc*))
        (gl-color 1.0 1.0 1.0 0.0)
        (gl-line-width 1.0)
        (and *display-proc* (*display-proc*))
        (gl-pop-matrix)
        (glut-swap-buffers))

      (define (reshape-fn w h)
        (set! vp-height h) (set! vp-width w)
        (and *reshape-proc* (*reshape-proc* w h)))

      (define (mouse-fn button state x y)
        (cond [(= state GLUT_UP)
               (set! prev-x -1) (set! prev-y -1) (set! prev-b #f)]
              [else
               (set! prev-x x) (set! prev-y y) (set! prev-b button)]))

      (define (motion-fn x y)
        (cond [(= prev-b GLUT_LEFT_BUTTON)
               (inc! rotx (* (/. (- y prev-y) vp-height) 90.0))
               (inc! roty (* (/. (- x prev-x) vp-width) 90.0))]
              [(= prev-b GLUT_MIDDLE_BUTTON)
               (inc! xlatx (* (/. (- x prev-x) vp-width (sqrt zoom)) 12.0))
               (inc! xlaty (* (/. (- prev-y y) vp-height (sqrt zoom)) 12.0))]
              [(= prev-b GLUT_RIGHT_BUTTON)
               (set! zoom (clamp (* (+ 1.0 (* (/. (- prev-y y) vp-height) 2.0))
                                    zoom)
                                 0.1 1000.0))])
        (set! prev-x x) (set! prev-y y)
        (glut-post-redisplay))

      (define (key-fn keycode x y)
        (cond [(hash-table-get *key-handlers* (integer->char keycode) #f)
               => (cut <> x y)]))

      (define (special-fn keycode x y)
        (cond [(hash-table-get *key-handlers* keycode #f) => (cut <> x y)]))

      (glut-display-func  display-fn)
      (glut-reshape-func  reshape-fn)
      (glut-mouse-func    mouse-fn)
      (glut-motion-func   motion-fn)
      (glut-keyboard-func key-fn)
      (glut-special-func  special-fn)

      (if rescue-errors
        (let1 eport (current-error-port)
          (let loop ()
            (guard (e [else (format eport "*** SIMPLE-VIEWER: ~a\n"
                                    (ref e'message))])
              (glut-main-loop))
            (loop)))
        (glut-main-loop))
      )))

;;
;; Default handlers (private)
;;

(define (default-reshape w h)
  (let1 ratio (/ h w)
    (gl-viewport 0 0 w h)
    (gl-matrix-mode GL_PROJECTION)
    (gl-load-identity)
    (gl-frustum -1.0 1.0 (- ratio) ratio 5.0 10000.0)
    (gl-matrix-mode GL_MODELVIEW)
    (gl-load-identity)
    (gl-translate 0.0 0.0 -40.0)
    ))

(define (default-grid)
  (gl-color 0.5 0.5 0.5 0.0)
  (gl-line-width 1.0)
  (gl-begin* GL_LINES
    (do-ec (: i -5 6)
           (begin
             (gl-vertex i 0 -5)
             (gl-vertex i 0 5)
             (gl-vertex -5 0 i)
             (gl-vertex 5  0 i)))))

(define (default-axis)
  (define (axis a b c)
    (gl-color a b c 0.0)
    (gl-begin* GL_LINES
      (gl-vertex 0 0 0)
      (gl-vertex a b c)))
  (gl-line-width 3.0)
  (axis 1.0 0.0 0.0)
  (axis 0.0 1.0 0.0)
  (axis 0.0 0.0 1.0))

;;
;; Set up default keymaps
;;

(simple-viewer-set-key! #\escape (lambda _ (exit)))

(provide "gl/simple/viewer")
