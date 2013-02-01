" Vim plugin for MetaWeblog 
"
" Copyright (C) 2013 Yugang LIU
"
" This program is free software: you can redistribute it and/or modify
" it under the terms of the GNU General Public License as published by
" the Free Software Foundation, either version 3 of the License, or
" (at your option) any later version.
"
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
"
" You should have received a copy of the GNU General Public License
" along with this program.  If not, see <http://www.gnu.org/licenses/>.
"
" Maintainer:Yugang LIU <liuyug@gmail.com>
" Version:1.0
" Last Change:Jan 21, 2013
" URL:https://github.com/liuyug/vim-metaweblog 

if exists("g:MetaWeblog_toggleView")
    finish
endif

let g:MetaWeblog_toggleView = 0
runtime password.vim

function! s:echo(msg)
    redraw!
    echomsg "MetaWeblog: " . a:msg
endfunction
function! s:echoWarning(msg)
    echohl warningmsg
    call s:echo(a:msg)
    echohl normal
endfunction
function! s:echoError(msg)
    echohl errormsg
    call s:echo(a:msg)
    echohl normal
endfunction

function! s:GetUsersBlogs()
python <<EOF
import vim
import xmlrpclib

def getUsersBlogs():
    try:
        vim.command('call s:echo("Fetch Blog information...")')
        proxy = xmlrpclib.ServerProxy(vim.eval('g:MetaWeblog_api_url'))
        info = proxy.metaWeblog.getUsersBlogs('',
            vim.eval('g:MetaWeblog_username'),
            vim.eval('g:MetaWeblog_password'))
        vim.command('call s:echo("Fetch Blog information... DONE")')
    except Exception as err:
        vim.command('call s:echoError("Fetch Blog information... %s")'% err)
        return
    vim.command('let s:blogName="%s"'% info[0].get('blogName'))
    vim.command('let s:blogurl="%s"'% info[0].get('url'))
    vim.command('let s:blogid="%s"'% info[0].get('blogid'))
    
getUsersBlogs()
EOF
endfunction

function! s:Init()
    let b:rst = bufname('%')
    if exists("s:blogName")
        return  
    endif
    let s:html = 'MetaWeblog_html'
    let s:recent = 'MetaWeblog_recent'
    call s:GetUsersBlogs()
endfunction

function! s:RstPost()
    call s:Init()
    if &filetype != 'rst' 
        call s:echoWarning('No rst file!')
        return
    endif
    if !exists('b:postid')
        let b:postid=0
    endif
    let postid = input('Please input postid (0 for new post)['. b:postid .']:',b:postid)
    if strlen(postid) == 0
        call s:echoWarning('No input postid, exit!')
        return
    endif 
    let b:postid = postid
    let old_cursor = getpos('.')
    call cursor(1,0)
    let lineno = search('^=')
    if lineno == 1
        let b:title = getline(lineno + 1)
    else
        let b:title = getline(lineno - 1)
    endif
    call cursor(1,1)
    let lineno = search('^:Categories:')
    if lineno > 1
        let b:categories = getline(lineno)[12:]
    else
        let b:categories = ''
    endif
    call setpos('.', old_cursor)
python <<EOF
import vim
import xmlrpclib

def rstPost():
    files={}
    def srcrepl(matchobj):
        if matchobj.group(2) in files:
            real_url = files[matchobj.group(2)]
        else:
            real_url=vim.eval('s:UploadFile("%s")'% matchobj.group(2))
            files[matchobj.group(2)] = real_url
        img = '<img%ssrc="%s" name="%s"'% (matchobj.group(1), real_url, matchobj.group(2))
        return img

    data={}
    data['title'] = vim.eval('b:title').strip()
    data['categories'] = vim.eval('b:categories').strip()
    vim.command('call s:echo("Convert RST to HTML")')
    winnr = vim.eval('winnr()')
    vim.command('call s:Rst2html("")')
    content = '\n'.join(vim.current.buffer)
    if isinstance(content, unicode):
       content = content.encode('utf-8')
    vim.command('bdelete')
    vim.command('%swincmd w'% winnr)
    postid = int(vim.eval('b:postid'))
    try:
        proxy = xmlrpclib.ServerProxy(vim.eval('g:MetaWeblog_api_url'))
        if postid == 0:
            vim.command('call s:echo("Check image and upload...")')
            data['description'] = re.sub(r'<img([^>]+)src="([^"]*)"',srcrepl, content)
            vim.command('call s:echo("Post article...")')
            postid = proxy.metaWeblog.newPost(
                vim.eval('s:blogid'),
                vim.eval('g:MetaWeblog_username'),
                vim.eval('g:MetaWeblog_password'),
                data, True)
            postid = int(postid)
            vim.command('let b:postid=%d'% postid)
        else:
            # don't upload image in rst edit mode
            # edit html after posted and upload image
            vim.command('call s:echo("Post article...")')
            data['description'] = content
            proxy.metaWeblog.editPost(
                postid,
                vim.eval('g:MetaWeblog_username'),
                vim.eval('g:MetaWeblog_password'),
                data,True)
        vim.command('call s:echo("Post article... DONE")')
        return postid
    except Exception as err:
        vim.command('call s:echoError("Post article... %s")'% err)
    return postid

rstPost()
EOF
endfunction

function! s:UploadFile(filename)
    call s:Init()
python <<EOF
import vim
import xmlrpclib
import mimetypes
import os.path

def uploadFile(filename):
    if not os.path.exists(filename):
        return ''
    vim.command('call s:echo("Upload file: %s")'% filename)
    mediaobj={}
    mediaobj['name']=filename
    mediaobj['type']=mimetypes.guess_type(filename)[0]
    mediaobj['bits']=xmlrpclib.Binary(open(filename,'rb').read())
    mediaobj['overwrite']=True
    try:
        proxy = xmlrpclib.ServerProxy(vim.eval('g:MetaWeblog_api_url'))
        data = proxy.metaWeblog.newMediaObject(
            vim.eval('s:blogid'),
            vim.eval('g:MetaWeblog_username'),
            vim.eval('g:MetaWeblog_password'),
            mediaobj)
        vim.command('call s:echo("Upload file: %s => %s")'% (filename,data['url']))
        return data['url']
    except Exception as err:
        vim.command('call s:echoError("Upload file: %s => %s")'% (filename,err))
        return ''

url = uploadFile(vim.eval('a:filename'))
vim.command('let url="%s"'% url)
EOF
return url
endfunction

function! s:UploadHereImgFile()
    if &filetype != 'html'
        call s:echoError('No html file!')
        return
    endif
    let filename = expand('<cfile>')
    let url = s:UploadFile(filename)
    if url == ''
        call s:echoError('Not found "'. filename .'"')
    else
        let ff = substitute(filename,'/','\\/','g')
        let uu = substitute(url,'/','\\/','g')
        execute '%s/src="'. ff .'"/src="'. uu .'"/g'
    endif
endfunction

function! s:HtmlPost()
    call s:Init()
    if &filetype != 'html'
        call s:echoError('No html file!')
        return
    endif
    if !exists('b:postid')
        let b:postid = 0
    endif
    let b:postid = input('Please input postid (0 for new post)['. b:postid .']:',b:postid)
    if !exists('b:title')
        let b:title = 'Unknown title'
    endif
    let b:title = input('Please input title ['. b:title .']:',b:title)

python<<EOF
import vim
import xmlrpclib

def htmlPost():
    data = {}
    data['title'] = vim.eval('b:title').strip()
    content = '\n'.join(vim.current.buffer)
    data['description'] = content
    if isinstance(content, unicode):
       content = content.encode('utf-8')
    postid = int(vim.eval('b:postid'))
    try:
        # upload image manually in html mode
        vim.command('call s:echo("Post article...")')
        proxy = xmlrpclib.ServerProxy(vim.eval('g:MetaWeblog_api_url'))
        if postid == 0:
            postid = proxy.metaWeblog.newPost(
                vim.eval('s:blogid'),
                vim.eval('g:MetaWeblog_username'),
                vim.eval('g:MetaWeblog_password'),
                data, True)
            postid = int(postid)
            vim.command('let b:postid=%d'% postid)
        else:
            proxy.metaWeblog.editPost(
                postid,
                vim.eval('g:MetaWeblog_username'),
                vim.eval('g:MetaWeblog_password'),
                data,True)
        vim.command('call s:echo("Post article... DONE")')
        return postid
    except Exception as err:
        vim.command('call s:echoError("Post article... %s")'% err)
        return

htmlPost()
EOF
endfunction

function! s:PostArticle()
    call s:Init()
    if &filetype == 'rst' 
        call s:RstPost()
    elseif &filetype == 'html' 
        call s:HtmlPost()
    endif
endfunction

function! s:GetPost()
    call s:Init()
python <<EOF
import vim
import xmlrpclib

def getPost():
    line = vim.eval('getline(".")')
    try:
        postid = int(line.split('-')[0].strip())
    except ValueError as err:
        return
    try:
        vim.command('call s:echo("Fetch article...")')
        proxy = xmlrpclib.ServerProxy(vim.eval('g:MetaWeblog_api_url'))
        data = proxy.metaWeblog.getPost(postid,
            vim.eval('g:MetaWeblog_username'),
            vim.eval('g:MetaWeblog_password'))
        vim.command('call s:echo("Fetch article... DONE")')
    except Exception as err:
        vim.command('call s:echoError("Fetch article... %s")'% err)
        return 
    if int(vim.eval('bufexists(s:html)')):
        vim.command('execute g:MetaWeblog_htmlWindow ."wincmd w"')
        vim.command('execute "edit ". s:html')
    else:
        vim.command('execute "botright new ". s:html')
        vim.command('let g:MetaWeblog_htmlWindow = winnr()')

    vim.command('let b:postid="%d"'% postid)
    title = data['title']
    if isinstance(title, unicode):
        title = title.encode('utf-8')
    vim.command('let b:title="%s"'% title)
    content = data['description']
    # for python2.x, str and unicode are difference
    if isinstance(content, unicode):
        content = content.encode('utf-8')
    vim.current.buffer.append(content.split('\n'))
    vim.command('setlocal filetype=html')
    vim.command('setlocal buftype=nowrite bufhidden=wipe noswapfile nowrap')

getPost()
EOF
endfunction

function! s:DeletePost()
    call s:Init()
python <<EOF
import vim
import xmlrpclib

def deletePost():
    line = vim.eval('getline(".")')
    lineno = int(vim.eval('line(".")'))
    try:
        postid = int(line.split('-')[0].strip())
    except ValueError as err:
        return
    if vim.eval('input("Do you delete %s ? [Y/N]:", "N")'% line).upper() != 'Y':
        return 
    try:
        vim.command('call s:echo("Delete...")')
        proxy = xmlrpclib.ServerProxy(vim.eval('g:MetaWeblog_api_url'))
        proxy.metaWeblog.deletePost('',
            postid,
            vim.eval('g:MetaWeblog_username'),
            vim.eval('g:MetaWeblog_password'),
            True)
        vim.command('call s:echo("Delete... DONE")')
    except Exception as err:
        vim.command('call s:echoError("Delete... %s")'% err)
        return 
    del vim.current.buffer[lineno-1]

deletePost()
EOF
endfunction

function! s:RefreshRecentPosts()
    execute '%delete'
    call s:GetRecentPosts()
endfunction

function! s:GetRecentPosts()
    call s:Init()
python <<EOF
import vim
import xmlrpclib

def getRecentPosts(numberOfPosts=0):
    try:
        vim.command('call s:echo("Fetch recent blogs...")')
        proxy = xmlrpclib.ServerProxy(vim.eval('g:MetaWeblog_api_url'))
        array = proxy.metaWeblog.getRecentPosts(
            vim.eval('s:blogid'),
            vim.eval('g:MetaWeblog_username'),
            vim.eval('g:MetaWeblog_password'),
            numberOfPosts)
        vim.command('call s:echo("Fetch recent blogs... DONE")')
    except Exception as err:
        vim.command('call s:echoError("Fetch recent blogs... %s")'% err)
        return 
    vim.current.buffer.append('%s:'% vim.eval('s:blogName'))
    vim.current.buffer.append('')
    for post in array:
        try:
            title = post['title']
            if isinstance(title, unicode):
                title = title.encode('utf-8')
            vim.current.buffer.append('%d - %s' % (post['postid'], title))
        except Exception as err:
            vim.command('call s:echoError("%s")'% err)

    vim.current.buffer.append('')
    vim.current.buffer.append('Press <Enter> to view current post')
    vim.current.buffer.append('Press "E" to edit current post')
    vim.current.buffer.append('Press "R" to refresh recent post')
    vim.current.buffer.append('Press "D" to delete current post')
getRecentPosts()
EOF
endfunction

function! s:ToggleRecentPostsView()
    call s:Init()
    if g:MetaWeblog_toggleView > 0
        execute g:MetaWeblog_recentPostsWindow . 'wincmd w'
        execute 'close'
        let g:MetaWeblog_toggleView = 0
    else 
        let g:MetaWeblog_toggleView = 1
        if bufexists(s:recent)
            execute g:MetaWeblog_recentPostsWindow .'wincmd w'
            execute 'edit '. s:recent
        else
            execute "30vnew ". s:recent
            let g:MetaWeblog_recentPostsWindow = winnr()
            setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
            setlocal cursorline
            execute 'nnoremap <buffer> <silent> <enter> <ESC>:MetaWeblogBrowsePost<CR>'
            execute 'nnoremap <buffer> <silent> e <ESC>:MetaWebloggetPost<CR>'
            execute 'nnoremap <buffer> <silent> r <ESC>:MetaWeblogrefreshRecentPosts<CR>'
            execute 'nnoremap <buffer> <silent> d <ESC>:MetaWeblogdeletePost<CR>'
        endif
        call s:RefreshRecentPosts()
    endif
endfunction

function! s:Rst2html(output)
    let title = b:title
    let rst = b:rst
    if a:output == ''
        execute 'botright 2new ' . s:html
        setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
        silent execute 'read !rst2html.py 
                \ --title="'. title .'"
                \ --syntax-highlight=short 
                \ --template=<(echo "\%(body_pre_docinfo)s\%(docinfo)s\%(body)s")
                \ --cloak-email-addresses
                \ '. rst 
    else
        silent execute '!rst2html.py 
                \ --title="' . title . '"
                \ --cloak-email-addresses
                \ '. rst .' '. a:output

    endif
endfunction

function! s:BrowserView(url)
    if exists('b:BrowserURL') && b:BrowserURL == a:url 
        call s:echo('Browser reload ...')
        if s:BrowserReload() == 0
            call s:echo('Browser reload ... DONE')
            return
        endif
        call s:echo('Browser reload ... FAILED! Open NEW Browser ...')
    else
        call s:echo('Open NEW Browser ...')
    endif
    let b:BrowserURL=a:url
    silent execute '!firefox ' . a:url . ' &'
    call s:echo('Open NEW Browser ... DONE')
endfunction

function! s:BrowsePost()
    call s:Init()
    let line = getline('.') 
    let len = stridx(line, ' - ')
    let postid = strpart(line, 0, len)
    let url = s:blogurl . 'posts/' . postid
    call s:BrowserView(url)
endfunction

function! s:BrowseServer()
    call s:Init()
    if exists('b:postid') && b:postid != 0
        let url = s:blogurl . 'posts/' . b:postid
    else
        call s:echoWarning('No postid, exit!')
        return
    endif
    call s:BrowserView(url)
endfunction

function! s:BrowseLocal()
    if &filetype != 'rst' 
        call s:echoWarning('No rst file!')
        return
    endif
    let b:rst = bufname('%')
    let old_cursor = getpos('.')
    call cursor(1,0)
    let lineno = search('^=')
    if lineno == 1
        let b:title = getline(lineno + 1)
    else
        let b:title = getline(lineno - 1)
    endif
    call setpos('.', old_cursor)
    let url = b:rst . '.html'
    call s:Rst2html(url)
    call s:BrowserView(url)
endfunction


function! s:BrowserReload()
    " please install firefox addon
    " https://addons.mozilla.org/en-US/firefox/addon/mozrepl/
python <<EOF
import sys, re
from telnetlib import Telnet

class Mozrepl(object):
    def __init__(self, ip="127.0.0.1", port=4242):
        self.ip = ip
        self.port = port

    def __enter__(self):
        try:
            self.t = Telnet(self.ip, self.port)
        except Exception as err:
            vim.command('call s:echoError("Please START mozrepl!")')
        return self

    def __exit__(self, type, value, traceback):
        if hasattr(self, 't'):
            self.t.close()
            del self.t

    def BrowserReload(self):
        if not hasattr(self, 't'):
            vim.command('let ret=1')
            return
        cmd = '''
        vimYo = content.window.pageYOffset
        vimXo = content.window.pageXOffset
        BrowserReload()
        content.window.scrollTo(vimXo,vimYo)
        repl.quit()
        '''
        self.t.write(cmd)
        vim.command('let ret=0')

with Mozrepl() as moz:
    moz.BrowserReload()
EOF
    return ret
endfunction

command! MetaWeblogBrowserReload         :call s:BrowserReload()
command! MetaWeblogBrowseLocal           :call s:BrowseLocal()
command! MetaWeblogBrowsePost            :call s:BrowsePost()
command! MetaWeblogBrowseServer          :call s:BrowseServer()

command! MetaWebloggetPost               :call s:GetPost()
command! MetaWeblogrefreshRecentPosts    :call s:RefreshRecentPosts()
command! MetaWeblogdeletePost            :call s:DeletePost()

command! MetaWeblogUploadHereImgFile     :call s:UploadHereImgFile()
command! MetaWeblogToggleView            :call s:ToggleRecentPostsView()
command! MetaWeblogPost                  :call s:PostArticle()

nnoremap <unique> <silent> <leader>bl <ESC>:MetaWeblogToggleView<CR>
nnoremap <unique> <silent> <leader>bp <ESC>:MetaWeblogPost<CR>
nnoremap <unique> <silent> <leader>bu <ESC>:MetaWeblogUploadHereImgFile<CR>
nnoremap <unique> <silent> <leader>bb <ESC>:MetaWeblogBrowseLocal<CR>
nnoremap <unique> <silent> <leader>bs <ESC>:MetaWeblogBrowseServer<CR>


