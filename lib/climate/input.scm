;;; -*- mode:scheme; coding:utf-8; -*-
;;;
;;; Copyright 2024 Takashi Kato <ktakshi@ymail.com>
;;; 
;;; Licensed under the Apache License, Version 2.0 (the "License");
;;; you may not use this file except in compliance with the License.
;;; You may obtain a copy of the License at
;;; 
;;;     http://www.apache.org/licenses/LICENSE-2.0
;;; 
;;; Unless required by applicable law or agreed to in writing, software
;;; distributed under the License is distributed on an "AS IS" BASIS,
;;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;;; See the License for the specific language governing permissions and
;;; limitations under the License.
;;;

;; command line input utilities
(library (climate input)
    (export argument->input-port
	    argument->string-content
	    argument->bytevector-content
	    call-with-argument-input-port
	    parse-attributed-argument)
    (import (rnrs)
	    (rnrs io ports)
	    (guile)
	    (srfi :13 strings))

;; argument
;; "-"     -> stdin (make sure only once, the procedure won't check)
;; "@file" -> file content -> bytevector -> input port
;; "aaa"   -> string->utf8 -> bytevector port
(define (file-suffix? s) (string-prefix? "@" s))
(define (stdin-mark? s) (string=? s "-"))

(define (argument->input-port in)
  ;; from stdin
  (cond ((stdin-mark? in) (standard-input-port))
	((file-suffix? in)
	 (let ((file (substring in 1 (string-length in))))
	   (open-bytevector-input-port
	    (call-with-input-file file get-bytevector-all #:binary #f))))
	(else (open-bytevector-input-port (string->utf8 in)))))

(define (argument->string-content arg)
  (if (or (stdin-mark? arg) (file-suffix? arg))
      (utf8->string (argument->bytevector-content arg))
      arg))

(define (argument->bytevector-content arg)
  (define (get-all in)
    (let-values (((out e) (open-bytevector-output-port)))
      (port-for-each (lambda (b) (put-u8 out b)) (lambda () (get-u8 in)))
      (e)))
  (if (or (stdin-mark? arg) (file-suffix? arg))
      (let ((v (get-all (argument->input-port arg))))
	(if (eof-object? v)
	    #vu8()
	    v))
      (string->utf8 arg)))

(define* (call-with-argument-input-port arg proc #:key (transcoder #f))
  (let ((in (argument->input-port arg)))
    (proc (if transcoder (transcoded-port in transcoder) in))))

(define* (parse-attributed-argument arg #:optional (default #f))
  (cond ((string-index arg #\|) =>
	 (lambda (index)
	   (let ((val (substring arg 0 index))
		 (att (substring arg (+ index 1) (string-length arg))))
	     (values val att))))
	(else (values arg default))))

)
