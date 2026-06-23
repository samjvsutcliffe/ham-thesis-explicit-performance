(in-package :cl-mpm/examples/collapse)
(sb-ext:restrict-compiler-policy 'speed  3 3)
(sb-ext:restrict-compiler-policy 'debug  0 0)
(sb-ext:restrict-compiler-policy 'safety 0 0)
;; (sb-ext:restrict-compiler-policy 'speed  0 0)
;; (sb-ext:restrict-compiler-policy 'debug  3 3)
;; (sb-ext:restrict-compiler-policy 'safety 3 3)
;; (setf cl-mpm/settings:*optimise-setting* cl-mpm/settings::*optimise-debug*)
;; (setf cl-mpm/settings:*optimise-setting* cl-mpm/settings::*optimise-debug*)
(defmethod cl-mpm::update-particle (mesh (mp cl-mpm/particle::particle-elastic) dt)
  (cl-mpm::update-particle-kirchoff mesh mp dt)
  ;; (cl-mpm::update-domain-stretch mesh mp dt)
  (cl-mpm::update-domain-polar mesh mp dt)
  )

(defun plot-domain ()
  (when *sim*
    (cl-mpm/plotter:simple-plot
     *sim*
     :plot :deformed
     :colour-func #'cl-mpm/particle::mp-strain-plastic-vm)))

(defun setup (&key (refine 1) (mps 2)
                (sort t)
                )
  (defparameter *sim* nil)
  (let ((mps-per-dim mps)
        (size '(32 16))
        (block-size '(8 8))
        )
    (let* ((E 1d6)
           (density 1d3)
           (sim (cl-mpm/setup::make-simple-sim
                 (/ 1d0 refine)
                 (mapcar (lambda (x) (* x refine)) size)
                 ;; :sim-type 'mpm-sim-test
                 :sim-type 'cl-mpm/aggregate::mpm-sim-agg-usf
                 ;; :sim-type 'cl-mpm/dynamic-relaxation::mpm-sim-dr-ul
                 :args-list
                 (list
                  :enable-aggregate t
                  :enable-fbar t
                  :max-split-depth 6
                  :mp-removal-size nil
                  :split-factor (/ 1.1d0 mps)
                  :enable-split nil
                  :gravity -10d0)))
           (h (cl-mpm/mesh:mesh-resolution (cl-mpm:sim-mesh sim))))
      (declare (double-float h density))
      (setf *sim* sim)
      (let* ((offset (* 0d0 h))
             (E 1d6)
             (length-scale 1d0)
             (init-stress 1d4)
             (gf 1000d0)
             (ductility (cl-mpm/damage::estimate-ductility-jirsek2004 gf length-scale init-stress E)))
        (format t "Ductility ~E~%" ductility)
        (when (<= ductility 1d0)
          (error "Ductility too small"))
        (cl-mpm::add-mps
         sim
         (cl-mpm/setup::make-block-mps
          (list 0d0 offset 0d0)
          block-size
          (mapcar (lambda (e) (* (/ e h) mps)) block-size)
          density
          ;; 'cl-mpm/particle::particle-elastic
          ;; :E E
          ;; :nu 0.3d0
          'cl-mpm/particle::particle-vm
          :E E
          :nu 0.3d0
          :rho 20d3
          ))
        (when sort
          (cl-mpm::domain-sort-mps sim))
        (defparameter *density* density)
        (cl-mpm/setup::set-mass-filter sim density :proportion 1d-15))))
  (cl-mpm/setup::setup-bcs
   *sim*
   :left (list 0 nil nil)
   :bottom (list nil 0 nil)
   :top (list nil nil nil))
  (format t "MPs: ~D~%" (length (cl-mpm:sim-mps *sim*)))
  (format t "Nodes: ~D~%" (array-total-size (cl-mpm/mesh:mesh-nodes (cl-mpm:sim-mesh *sim*))))
  (setf *step-count* 0)
  )

(defparameter *data-file* (merge-pathnames "./data.csv"))

(defun output-perf-header (file)
  (with-open-file (stream file :direction :output :if-exists :supersede)
    (format stream "mps,refine,threads,mp-total,iters,time~%")))

(defun output-perf-data (file mps refine threads mp-total iters dt)
  (with-open-file (stream file :direction :output :if-exists :append)
    (format stream "~D,~D,~D,~D,~D,~f~%"
            mps
            refine
            threads
            mp-total
            iters
            dt)))


(defun output-timing-header (output-dir)
  (with-open-file (stream (merge-pathnames "disp.csv" output-dir) :direction :output :if-exists :supersede)
    (format stream "step,time~%")
    (format stream "0,0.0~%")
    ))

(defun output-timing-data (output-dir step dt)
  (with-open-file (stream (merge-pathnames "disp.csv" output-dir) :direction :output :if-exists :append)
    (format stream "~D,~f~%"
            step
            dt)))

(defun run (&key (output-dir "./output/")
              (dt-scale 1d0)
              (plot nil)
              )
  (let ((step 0)
        (start (get-internal-real-time))
        )
    (cl-mpm/dynamic-relaxation::run-time
     *sim*
     :output-dir output-dir
     :plotter (lambda (sim)
                (when plot (plot-domain))
                ;; (vgplot:print-plot (merge-pathnames (format nil "outframes/frame_~5,'0d.png" step))
                ;;                    :terminal "png size 1920,1080")
                (incf step))
     :post-conv-step (lambda (s)
                       (output-timing-header output-dir)
                       (setf start (get-internal-real-time))
                       )
     :post-iter-step (lambda (s)
                       (let* ((end (get-internal-real-time))
                              (units internal-time-units-per-second)
                              (dt (/ (- end start) units)))
                         (incf step)
                         (output-timing-data
                          output-dir
                          step
                          dt)))
     :conv-criteria 1d-3
     :initial-quasi-static nil
     :damping 1d-1
     :dt 0.5d0
     :total-time 5d0
     :save-vtk-dr nil
     :save-vtk-loadstep nil
     :dt-scale 0.5d0)))

(defparameter *step-count* 0)
(defmethod cl-mpm::update-sim :after ((sim cl-mpm::mpm-sim-usf))
  (incf *step-count*))

;; (defun test ()
;;   (ensure-directories-exist "./data/")
;;   (cl-mpm::set-workers 8)
;;   ;; (dolist (mp (list 2))
;;   ;;   (dolist (r (list 2 3 4))
;;   ;;     (let (;; (r 2)
;;   ;;           ;; (mp 2)
;;   ;;           )
;;   ;;       (setup :refine r :mps mp)
;;   ;;       (run :output-dir (merge-pathnames (format nil "./output-~D_~D/" r mp) "./data/")))))

;;   (let ((mp 2)
;;         (r 1))
;;     (dolist (class (list 'cl-mpm::mpm-sim-usf
;;                          'cl-mpm/aggregate::mpm-sim-agg-usf
;;                          'cl-mpm::mpm-sim-usl
;;                          'cl-mpm::mpm-sim-musl
;;                          ))
;;       (let (;; (r 2)
;;             ;; (mp 2)
;;             )
;;         (setup :refine r :mps mp)
;;         ;; (setf (cl-mpm/aggregate::sim-enable-aggregate *sim*) nil)
;;         (run :output-dir (merge-pathnames (format nil "./output-~A/" class) "./data/")))))
;;   )
(defun test ()
  (ensure-directories-exist "./data/")

  (let ((file (merge-pathnames "timing.csv")))
    (output-perf-header file)
    (let ((mp 4)
          (r 4))
      (dolist (th (reverse (list 1 2 4 8 12 16)))
        (let (;; (r 2)
              ;; (mp 2)
              )
          (cl-mpm::set-workers th)
          (setup :refine r :mps mp)
          (plot-domain)
          ;; (setf (cl-mpm/aggregate::sim-enable-aggregate *sim*) nil)
          (let ((start (get-internal-real-time)))
            (run :output-dir (merge-pathnames (format nil "./output-~A/" th) "./data/")
                 :plot t
                 )
            (plot-domain)
            (let* ((end (get-internal-real-time))
                   (units internal-time-units-per-second)
                   (dt (/ (- end start) units)))
              (format t "R - ~D - MP ~D - dt ~E~%" r mp dt)
              (output-perf-data
               file
               mp
               r
               th
               (length (cl-mpm:sim-mps *sim*))
               *step-count*
               dt))))))))

(defun test-mps ()
  (ensure-directories-exist "./data/")

  (let ((file (merge-pathnames "timing_mps.csv")))
    (output-perf-header file)
    (let ((th 8)
          (r 4))
      (dolist (mp (list 2 3 4 5 6))
        (let ()
          (cl-mpm::set-workers th)
          (setup :refine r :mps mp)
          (plot-domain)
          ;; (setf (cl-mpm/aggregate::sim-enable-aggregate *sim*) nil)
          (let ((start (get-internal-real-time)))
            (run :output-dir (merge-pathnames (format nil "./output-~A/" th) "./data/")
                 :plot t
                 )
            (plot-domain)
            (let* ((end (get-internal-real-time))
                   (units internal-time-units-per-second)
                   (dt (/ (- end start) units)))
              ;; (format t "R - ~D - MP ~D - dt ~E~%" r mp dt)
              (output-perf-data
               file
               mp
               r
               th
               (length (cl-mpm:sim-mps *sim*))
               *step-count*
               dt))))))))


(defun test-perf ()
  (ensure-directories-exist "./data/")
  (cl-mpm::set-workers 8)
  (let ((file (merge-pathnames "timing.csv")))
    (output-perf-header file)
    (dolist (r (list 1 2 3 4 5 6))
      (dolist (mp (list 4))
        (when (<= (* (expt mp 2) (expt (* 8 r) 2)) (* 1 65536))
          (setup :refine r :mps mp)
          (setf (cl-mpm/aggregate::sim-enable-aggregate *sim*) nil)
          (setf (cl-mpm:sim-dt *sim*) (cl-mpm/setup::estimate-elastic-dt *sim*))
          (let ((start (get-internal-real-time)))
            (time
             (dotimes (i 10)
               (cl-mpm:update-sim *sim*)))
            (let* ((end (get-internal-real-time))
                   (units internal-time-units-per-second)
                   (dt (/ (- end start) units)))
              (format t "R - ~D - MP ~D - dt ~E~%" r mp dt)
              (output-perf-data
               file
               mp
               r
               dt))))))))


(defun test-sort ()
  (ensure-directories-exist "./data/")
  (cl-mpm::set-workers 16)
  (dolist (sort (list t nil))
    (dolist (r (list 8))
      (dolist (mp (list 8))
        (sb-ext:gc :full t)
        (setup :refine r :mps mp :sort sort)
        (setf (cl-mpm/aggregate::sim-enable-aggregate *sim*) nil)
        (setf (cl-mpm:sim-dt *sim*) (cl-mpm/setup::estimate-elastic-dt *sim*))
        (cl-mpm:update-sim *sim*)
        (let ((start (get-internal-real-time)))
          (time
           (dotimes (i 10)
             (cl-mpm:update-sim *sim*)))
          (let* ((end (get-internal-real-time))
                 (units internal-time-units-per-second)
                 (dt (/ (- end start) units)))
            (format t "R - ~D - MP ~D - dt ~E~%" r mp dt)
            ))))))
