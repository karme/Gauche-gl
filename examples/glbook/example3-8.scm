;; Example 3-8  Reversing the Geometirc Processing Pipeline

(use gl)
(use gl.glut)

(define *shoulder* 0)
(define *elbow* 0)

(define (disp)
  (gl-clear |GL_COLOR_BUFFER_BIT|)
  (gl-flush)
  )

(define (reshape w h)
  (gl-viewport 0 0 w h)
  (gl-matrix-mode |GL_PROJECTION|)
  (gl-load-identity)
  (glu-perspective 45.0 (/ w h) 1.0 100.0)
  (gl-matrix-mode |GL_MODELVIEW|)
  (gl-load-identity)
  )

(define (mouse button state x y)
  (cond
   ((= button |GLUT_LEFT_BUTTON|)
    (if (= state |GLUT_DOWN|)
        (let* ((viewport (gl-get-integer |GL_VIEWPORT|))
               (mvmatrix (gl-get-double  |GL_MODELVIEW_MATRIX|))
               (projmatrix (gl-get-double |GL_PROJECTION_MATRIX|))
               (real-y   (- (s32vector-ref viewport 3) y 1)))
          (format #t "Coordinates at cursor are (~4d, ~4d)\n" x real-y)
          (receive (wx wy wz)
              (glu-un-project x real-y 0.0 mvmatrix projmatrix viewport)
            (format #t "World coords at z=0.0 are (~s, ~s, ~s)\n"
                    wx wy wz))
          (receive (wx wy wz)
              (glu-un-project x real-y 1.0 mvmatrix projmatrix viewport)
            (format #t "World coords at z=1.0 are (~s, ~s, ~s)\n"
                    wx wy wz))
          )))
   ((= button |GLUT_RIGHT_BUTTON|)
    (if (= state |GLUT_DOWN|)
        (exit 0)))
   ))

(define (main args)
  (glut-init args)
  (glut-init-display-mode (logior |GLUT_SINGLE| |GLUT_RGB|))
  (glut-init-window-size 500 500)
  (glut-init-window-position 100 100)
  (glut-create-window *program-name*)
  (glut-display-func disp)
  (glut-reshape-func reshape)
  (glut-mouse-func mouse)
  (glut-main-loop)
  0)