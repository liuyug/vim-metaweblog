==============
VIM MetaWeblog
==============
:Author: Yugang LIU <liuyug # gmail.com>

Submit your *RST* article in VIM with metaweblog interface. 

Feature:

+ direct submit *RST* article to Blog.
+ automatic upload image resource and fix link.
+ browse recent blogs
+ delete recent blog

Install
=======
1. Copy ``plugin/metaweblog.vim`` to ``~/.vim/plugin/metaweblog.vim``

2. Create new configuration file in ``~/.vim/password.vim``:

.. code:: vim

    # password.vim
    let g:MetaWeblog_api_url='http://www.is-programmer.com/xmlrpc'
    let g:MetaWeblog_username='username'
    let g:MetaWeblog_password='password'

3. Install CSS to support style:

.. code:: bash

    cat /usr/lib/python2.6/site-packages/docutils/writers/html4css1/html4css1.css > blog.css
    pygmentize -S monokai -f html -a pre.code >> blog.css

4. Upload blog.css to Blog site.

Guide
======
VIM shortcut keys:

.. code:: vim

    <leader>bl      toggle recent blog view
    <leader>bn      submit new article 

TODO
=====
+ How to know original RST location by the article in Blog? 

