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
" Last Change:Jan 21, 2013
" URL: http://...

if exists("g:MetaWeblog_toggleView")
    finish
endif

let g:MetaWeblog_toggleView = 0
runtime password.vim

function! s:GetUsersBlogs()
python <<EOF
import vim
import xmlrpclib

def getUsersBlogs():
    try:
        print('Wait for Blog information.')
        proxy = xmlrpclib.ServerProxy(vim.eval('g:MetaWeblog_api_url'))
        info = proxy.metaWeblog.getUsersBlogs('',
            vim.eval('g:MetaWeblog_username'),
            vim.eval('g:MetaWeblog_password'))
    except Exception as err:
        print(err)
        return
    vim.command('let s:blogName="%s"'% info[0].get('blogName'))
    vim.command('let s:blogurl="%s"'% info[0].get('url'))
    vim.command('let s:blogid="%s"'% info[0].get('blogid'))

getUsersBlogs()
EOF
endfunction

function! s:Init()
    if exists("s:blogName")
        return  
    endif
    let s:rst = bufname('%')
    let s:html = 'MetaWeblog_html'
    let s:recent = 'MetaWeblog_recent'
    call s:GetUsersBlogs()
endfunction

function! s:BrowseView(url)
    silent execute '!firefox ' . a:url . ' &'
endfunction

function! s:Rst2html()
    execute 'botright 2new ' . s:html
    setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
    silent execute 'read !rst2html.py 
            \ --syntax-highlight=short ' . s:rst . '
            \ --template=<(echo "\%(body_pre_docinfo)s\%(docinfo)s\%(body)s")'
endfunction

function! s:NewPost()
    call s:Init()
    if &filetype != 'rst' 
        echo 'No rst file!'
        return
    endif
    call cursor(1,1)
    let lineno = search('^=')
    if lineno == 1
        let b:title = getline(lineno - 1)
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
    call cursor(1,1)
    let lineno = search('^:Tags:')
    if lineno > 1
        let b:tags = getline(lineno)[6:]
    else
        let b:tags = ''
    endif

python <<EOF
import vim
import xmlrpclib
import mimetypes

def uploadFile(filename):
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
        return data['url']
    except Exception as err:
        print(err)


def newPost():
    files={}
    def srcrepl(matchobj):
        if matchobj.group(2) in files:
            real_url = files[matchobj.group(2)]
        else:
            real_url = uploadFile(matchobj.group(2))
            files[matchobj.group(2)] = real_url
        img = '<img%ssrc="%s"'% (matchobj.group(1), real_url)
        return img
    data={}
    data['title'] = vim.eval('b:title').strip()
    data['categories'] = vim.eval('b:categories').strip()
    data['tags'] = vim.eval('b:tags').strip()
    vim.command('call s:Rst2html()')
    #vim.command('execute "buffer " . s:html')
    content = '\n'.join(vim.current.buffer)
    vim.command('close')
    data['description'] = re.sub(r'<img([^>]+)src="([^"]*)"',srcrepl, content)
    try:
        print('Wait for submit.')
        proxy = xmlrpclib.ServerProxy(vim.eval('g:MetaWeblog_api_url'))
        postid = proxy.metaWeblog.newPost(
            vim.eval('s:blogid'),
            vim.eval('g:MetaWeblog_username'),
            vim.eval('g:MetaWeblog_password'),
            data, True)
    except Exception as err:
        print(err)
    return int(postid)

newPost()
EOF
endfunction

function! s:BrowsePost()
    call s:Init()
python <<EOF
import vim
import xmlrpclib

def browsePost():
    line = vim.eval('getline(".")')
    try:
        postid = int(line.split('-')[0].strip())
        url = '%sposts/%d'% (vim.eval('s:blogurl'), postid)
    except ValueError as err:
        url = vim.eval('s:blogurl')
    vim.command('call s:BrowseView("%s")'% url)

browsePost()
EOF
endfunction

function! s:SaveHtmlPost()
    call s:Init()
    if &filetype != 'html'
        echo 'No html file!'
        return
    endif
python<<EOF
    data = {}
    data['title'] = vim.eval('b:title').strip()
    #vim.command('execute "buffer " . s:html')
    content = '\n'.join(vim.current.buffer)
    data['description'] = content
    print(data)
    try:
        proxy.metaWeblog.editPost(
            int(vim.eval('b:postid')),
            vim.eval('g:MetaWeblog_username'),
            vim.eval('g:MetaWeblog_password'),
            data,True)
    except Exception as err:
        print(err)
        return
EOF 
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
        print('Wait for fetching article.')
        proxy = xmlrpclib.ServerProxy(vim.eval('g:MetaWeblog_api_url'))
        data = proxy.metaWeblog.getPost(postid,
            vim.eval('g:MetaWeblog_username'),
            vim.eval('g:MetaWeblog_password'))
    except Exception as err:
        print(err)
        return 
    if int(vim.eval('bufexists(s:html)')):
        vim.command('execute g:MetaWeblog_htmlWindow ."wincmd w"')
        vim.command('execute "edit ". s:html')
    else:
        vim.command('execute "botright new ". s:html')
        vim.command('let g:MetaWeblog_htmlWindow = winnr()')

    vim.command('let b:postid="%d"'% postid)
    vim.command('let b:title="%s"'% data['title'])
    content = data['description']
    # for python2.x, str and unicode are difference
    if isinstance(content, unicode):
       content = content.encode('utf-8')
    vim.current.buffer.append(content.split('\n'))
    vim.command('setlocal filetype=html')
    vim.command('setlocal buftype=nowrite bufhidden=wipe noswapfile nowrap')
    vim.command('nnoremap <buffer> <silent> <leader>bs <ESC>:MetaWeblogsavePost<CR>')

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
    try:
        print('Wait for delete.')
        proxy = xmlrpclib.ServerProxy(vim.eval('g:MetaWeblog_api_url'))
        proxy.metaWeblog.deletePost('',
            postid,
            vim.eval('g:MetaWeblog_username'),
            vim.eval('g:MetaWeblog_password'),
            True)
    except Exception as err:
        print(err)
        return 
    del vim.current.buffer[lineno-1]

deletePost()
EOF
endfunction

function! s:RefreshRecentPosts()
    " del vim.current.buffer[:]
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
        print('Wait for fetching recent blogs.')
        proxy = xmlrpclib.ServerProxy(vim.eval('g:MetaWeblog_api_url'))
        array = proxy.metaWeblog.getRecentPosts(
            vim.eval('s:blogid'),
            vim.eval('g:MetaWeblog_username'),
            vim.eval('g:MetaWeblog_password'),
            numberOfPosts)
    except Exception as err:
        print(err)
        return 
    vim.current.buffer.append('%s:'% vim.eval('s:blogName'))
    vim.current.buffer.append('')
    for post in array:
        vim.current.buffer.append('%d - %s' % (post['postid'],post['title']))

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
            execute 'nnoremap <buffer> <silent> <enter> <ESC>:MetaWeblogbrowsePost<CR>'
            execute 'nnoremap <buffer> <silent> e <ESC>:MetaWebloggetPost<CR>'
            execute 'nnoremap <buffer> <silent> r <ESC>:MetaWeblogrefreshRecentPosts<CR>'
            execute 'nnoremap <buffer> <silent> d <ESC>:MetaWeblogdeletePost<CR>'
        endif
        call s:RefreshRecentPosts()
    endif
endfunction


command! MetaWeblogbrowsePost            :call s:BrowsePost()
command! MetaWebloggetPost               :call s:GetPost()
command! MetaWeblogrefreshRecentPosts    :call s:RefreshRecentPosts()
command! MetaWeblogdeletePost            :call s:DeletePost()
command! MetaWeblogToggleView            :call s:ToggleRecentPostsView()
command! MetaWeblognewPost               :call s:NewPost()
command! MetaWeblogsavePost              :call s:SaveHtmlPost()

noremap <silent> <leader>bl <ESC>:MetaWeblogToggleView<CR>
noremap <silent> <leader>bn <ESC>:MetaWeblognewPost<CR>




