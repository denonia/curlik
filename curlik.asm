BITS 64

%define ACCESS_TOKEN            '1234567890:AAFzm1VOptJXbtDXjyUx83bUv4suKFciVDU'

%define SYS_NANOSLEEP           35

%define CURL_GLOBAL_DEFAULT     3
%define CURLOPT_URL             10002
%define CURLOPT_HTTPHEADER      10023
%define CURLOPT_POSTFIELDS      10015
%define CURLOPT_WRITEFUNCTION   20011

extern curl_global_init, curl_global_cleanup
extern curl_easy_init, curl_easy_cleanup
extern curl_easy_setopt, curl_easy_perform
extern curl_slist_append
extern printf, sprintf
extern strlen, strcmp, strtok
extern fflush
extern atoi

SECTION .data
    poll_url      db 'https://api.telegram.org/bot', ACCESS_TOKEN, '/getUpdates?offset=%d', 0
    poll_timespec:
        tv_sec    dq 0
        tv_nsec   dq 500000 ; 0.5s

    resp_url      db 'https://api.telegram.org/bot', ACCESS_TOKEN, '/sendDice', 0
    resp_payload  db `{"chat_id":%s,"emoji":"%s}"`, 0
    resp_ct       db 'Content-Type: application/json', 0

    delim         db `[]{},:\"`, 0
    tok_update_id db 'update_id', 0
    tok_id        db 'id', 0
    tok_emoji     db 'emoji', 0

SECTION .bss
    curl_poll     resq 1
    curl_sender   resq 1

    last_update   resd 1
    id            resq 1
    emoji         resq 1
    payload       resb 256

SECTION .text
    global main

advance:
    xor  rdi, rdi
    mov  rsi, delim
    call strtok
    ret

handle_update:
    push rax

    cmp  rdx, 23 ; {"ok":true,"result":[]}
    je   .end

    mov  rsi, delim
    call strtok

.tok:
    call advance

    cmp  rax, 0
    je   .tok_end

    mov  rdi, rax
    mov  rsi, tok_update_id
    call strcmp
    cmp  rax, 0
    je   .get_uid
    
    mov  rsi, tok_id
    call strcmp
    cmp  rax, 0
    je   .get_cid

    mov  rsi, tok_emoji
    call strcmp
    cmp  rax, 0
    je   .send_emoji

    jmp  .tok

.get_uid:
    call advance

    mov  rdi, rax
    call atoi
    inc  rax

    mov  [last_update], rax
    jmp  .tok

.get_cid:
    call advance

    mov  [id], rax
    jmp  .tok

.send_emoji:
    call advance

    mov  rdi, payload
    mov  rsi, resp_payload
    mov  rdx, [id]
    mov  rcx, rax
    call sprintf

    ; headers
    mov  rdi, 0
    mov  rsi, resp_ct
    call curl_slist_append

    mov  rdi, [curl_sender]
    mov  rsi, CURLOPT_HTTPHEADER
    mov  rdx, rax
    call curl_easy_setopt

    mov  rdi, [curl_sender]
    mov  rsi, CURLOPT_URL
    mov  rdx, resp_url
    call curl_easy_setopt
    cmp  rax, 0
    jne  error

    mov  rdi, [curl_sender]
    mov  rsi, CURLOPT_POSTFIELDS
    mov  rdx, payload
    call curl_easy_setopt
    cmp  rax, 0
    jne  error

    mov  rdi, [curl_sender]
    call curl_easy_perform

    jmp .tok

.tok_end:    
    xor  rdi, rdi
    call fflush

    cmp  rax, 0
    jne  error
 
.end:
    pop  rax
    ret

handle_resp:
    ret

main: 
    push rbp
    mov  rbp, rsp

    mov  rdi, CURL_GLOBAL_DEFAULT
    call curl_global_init

    call curl_easy_init
    cmp  rax, 0
    je   error
    mov  [curl_poll], rax

    call curl_easy_init
    cmp  rax, 0
    je   error
    mov  [curl_sender], rax

    ; setting up long polling
    mov  rdi, [curl_poll]
    mov  rsi, CURLOPT_WRITEFUNCTION
    mov  rdx, handle_update
    call curl_easy_setopt
    
    mov  rdi, [curl_sender]
    mov  rsi, CURLOPT_WRITEFUNCTION
    mov  rdx, handle_resp
    call curl_easy_setopt

    cmp  rax, 0
    jne  error

    ; getUpdates url buffer
    sub  rsp, 64
.poll:
    lea  rdi, [rbp-64]
    mov  rsi, poll_url
    mov  rdx, [last_update]
    call sprintf

    mov  rdi, [curl_poll]
    mov  rsi, CURLOPT_URL
    lea  rdx, [rbp-64]
    call curl_easy_setopt

    mov  rdi, [curl_poll]
    call curl_easy_perform

    mov  rax, SYS_NANOSLEEP
    mov  rdi, poll_timespec
    xor  rsi, rsi        
    syscall

    jmp  .poll

    ; todo handle signals?

.cleanup:
    mov  rdi, [curl_sender]
    call curl_easy_cleanup

    mov  rdi, [curl_poll]
    call curl_easy_cleanup

    call curl_global_cleanup

    pop  rbp
    xor  rax, rax
    ret

error:
    pop  rbp
    ret

