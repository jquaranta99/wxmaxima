;=============================================================================
;    (c) copyright 1988	 Kent State University  kent, ohio 44242 
;		all rights reserved.
;
; Authors:  Paul S. Wang, Barbara Gates
; Permission to use this work for any purpose is granted provided that
; the copyright notice, author and support credits above are retained.
;=============================================================================

(include-if (null (getd 'wrs)) convmac.l)

(declare (special *gentran-dir tempvartype* tempvarname* tempvarnum* genstmtno*
	genstmtincr* *symboltable* *instk* *stdin* *currin* *outstk*
	*stdout* *currout* *outchanl* *lispdefops* *lisparithexpops*
	*lisplogexpops* *lispstmtops* *lispstmtgpops*))
;;  -----------  ;;
;;  templt.l     ;;    template processing routines
;;  -----------  ;;

(declare (special *cr* *slash* *vexptrm))

;;                               ;;
;;  1. text processing routines  ;;
;;                               ;;


;;  fortran  ;;


(de procforttem ()
  (prog (c)
	(setq c (procfortcomm))
	(while (neq c '$eof$)
	       (cond ((eq c *cr*)
		      (progn (pprin2 *cr*)
			     (setq c (procfortcomm))))
                     ((eq c '<)
		      (setq c (readc nil '$eof$))
		      (cond ((eq c '<)
			     (setq c (procactive)))
			    (t
			     (pprin2 '<)
			     (pprin2 c)
			     (setq c (readc nil '$eof$)))))
		     (t
		      (progn (pprin2 c)
			     (setq c (readc nil '$eof$))))))))

(de procfortcomm ()
  ; <col 1>c ... <cr> ;
  ; <col 1>c ... <cr> ;
  ; <col 1>* ... <cr> ;
  (prog (c)
	(while (member (setq c (readc nil '$eof$)) '(c c *))
	       (progn (pprin2 c)
		      (repeat (pprin2 (setq c (readc nil '$eof$)))
			      (eq c *cr*))))
	(return c)))


;;  ratfor  ;;


(de procrattem ()
  (prog (c)
	(setq c (readc nil '$eof$))
	(while (neq c '$eof$)
	       (cond ((eq c '|#|)
		      (setq c (procratcomm)))
                     ((eq c '<)
		      (setq c (readc nil '$eof$))
		      (cond ((eq c '<)
			     (setq c (procactive)))
			    (t
			     (pprin2 '<)
			     (pprin2 c)
			     (setq c (readc nil '$eof$)))))
		     (t
		      (progn (pprin2 c)
			     (setq c (readc nil '$eof$))))))))

(de procratcomm ()
  ; # ... <cr> ;
  (prog (c)
	(pprin2 '|#|)
	(while (neq (setq c (readc nil '$eof$)) *cr*)
	       (pprin2 c))
	(pprin2 *cr*)
	(return (readc nil '$eof$))))


;;  c  ;;


(de procctem ()
  (prog (c)
	(setq c (readc nil '$eof$))
	(while (neq c '$eof$)
	       (cond ((eq c *slash*)
		      (setq c (procccomm)))
                     ((eq c '<)
		      (setq c (readc nil '$eof$))
		      (cond ((eq c '<)
			     (setq c (procactive)))
			    (t
			     (pprin2 '<)
			     (pprin2 c)
			     (setq c (readc nil '$eof$)))))
		     (t
		      (progn (pprin2 c)
			     (setq c (readc nil '$eof$))))))))

(de procccomm ()
  ; /* ... */ ;
  (prog (c)
	(pprin2 *slash*)
	(setq c (readc nil '$eof$))
	(cond ((eq c '*)
	       (progn (pprin2 c)
		      (setq c (readc nil '$eof$))
		      (repeat (progn (while (neq c '*)
					    (progn (pprin2 c)
						   (setq c (readc nil '$eof$))))
				     (pprin2 c)
				     (setq c (readc nil '$eof$)))
			      (eq c *slash*))
		      (pprin2 c)
		      (setq c (readc nil '$eof$)))))
	(return c)))


;;                                        ;;
;;  2. template file active part handler  ;;
;;                                        ;;


(defun procactive ()
  ;  procactive reads vaxima expressions and statements inside "<<" and ">>"  ;
  ;  and mevals each.                                                         ;
  (prog (vexp vexptrm c)
   loop (setq vexp ($readvexp *currin*))
	(setq vexptrm *vexptrm)
	(meval vexp)
	(cond ((member vexptrm '(#\eof #/>))
	       (return (cond ((equal (setq c (readc nil '$eof$)) *cr*)
			      (readc nil '$eof$))
			     (c)))))
	(go loop)))

(defun $readvexp (in)
  ;  $readvexp is the parser for expressions and statements        ;
  ;  inside "<<" and ">>" within the template file.                ;
  ;                                                                ;
  ;  "/*  ...  */" can be used for comments inside "<<" and ">>".  ;
  (prog (test oldst st iport)
      (setq iport (cdr in))
   loop (setq test (tyi iport))
   c    (cond ((and (equal test #/*)
		    st
		    (equal (car st) #//))
	        (do ((ch1 (tyi iport) ch2) (ch2))
		   ((or (and (equal ch1 #/*) (equal ch2 #//))
			(equal ch2 #\eof))
		    (setq st (cdr st)))
		   (setq ch2 (tyi iport)))
	        (go loop))
	      ((member test '(#\space #\tab #\lf))
	       (cond ((null st) (go loop))))
	      ((and (equal test #/>)
		    st
		    (equal (car st) #/>))
	       (setq *vexptrm test)
	       (go d))
	      ((member test '(#/; #/$ #\eof))
	       (setq *vexptrm test)
	       (go d))
	      ((equal test #/\)
	       (setq st (cons test st)
		     test (tyi iport))))
	(setq st (cons test st))
	(go loop)
   d    (cond ((and (null st)
		    (not (member *vexptrm '(#\lf #\eof #/>))))
	       (go loop)))
	(setq oldst st)
	(cond ((null st) (return nil))
	      ((setq test (parse2)) (return (car test))))
	(setq test (tyi iport))
	(go c)))
