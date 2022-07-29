# 解析init.rc

 /[system](http://androidxref.com/6.0.0_r1/xref/system/)/[core](http://androidxref.com/6.0.0_r1/xref/system/core/)/[init](http://androidxref.com/6.0.0_r1/xref/system/core/init/)/[init_parser.cpp](http://androidxref.com/6.0.0_r1/xref/system/core/init/init_parser.cpp)



##  init_parse_config_file("/init.rc");

```
int init_parse_config_file(const char* path) {
    Timer t;
    std::string data;
    //data参数读取init.rc内容
    if (!read_file(path, &data)) {
        return -1;
    }
    //尾部添加\n
    data.push_back('\n');
    //1.解析
    parse_config(path, data);
    dump_parser_state();

    NOTICE("(Parsing %s took %.2fs.)\n", path, t.duration());
    return 0;
}
```

## 1.parse_config(path, data)

```
static void parse_config(const char *fn, const std::string& data)
{   
    //1.1双向链表
    struct listnode import_list;
    struct listnode *node;
    //INIT_PARSER_MAXARGS 64
    char *args[INIT_PARSER_MAXARGS];

    int nargs = 0;
    //1.2
    parse_state state;
    //state初始化值
    state.filename = fn;
    state.line = 0;
    //赋值文本头指针
    state.ptr = strdup(data.c_str());  // TODO: fix this code!
    state.nexttoken = 0;
    state.parse_line = parse_line_no_op;
     //1.3初始化链表 头和尾都指向自己 
    list_init(&import_list);
    state.priv = &import_list;
   
    for (;;) {
        //遍历data数据i++的方式 一个字节一个字节编译
        switch (next_token(&state)) {
        case T_EOF:
            state.parse_line(&state, 0, 0);
            goto parser_done;
        case T_NEWLINE:
            state.line++;
            if (nargs) {
                int kw = lookup_keyword(args[0]);
                //开始匹配kw
                if (kw_is(kw, SECTION)) {
                    state.parse_line(&state, 0, 0);
                    //3.根据kw_is匹配出来 k_service,k_on,K_import,
                    parse_new_section(&state, kw, nargs, args);
                } else {
                    state.parse_line(&state, nargs, args);
                }
                nargs = 0;
            }
            break;
        case T_TEXT:
            if (nargs < INIT_PARSER_MAXARGS) {
                args[nargs++] = state.text;
            }
            break;
        }
    }

parser_done:
    list_for_each(node, &import_list) {
         struct import *import = node_to_item(node, struct import, list);
         int ret;

         ret = init_parse_config_file(import->filename);
         if (ret)
             ERROR("could not import file '%s' from '%s'\n",
                   import->filename, fn);
    }
}
```

### 1.1listnode

```
struct listnode
{
    struct listnode *next;
    struct listnode *prev;
};
```

### 1.2 struct parse_state

```
struct parse_state
{
    char *ptr;
    char *text;
    int line;
    int nexttoken;
    void *context;
    void (*parse_line)(struct parse_state *state, int nargs, char **args);
    const char *filename;
    void *priv;
};
```

### 1.3list_init(&import_list)

```
static inline void list_init(struct listnode *node)
{
    node->next = node;
    node->prev = node;
}
```

## 2next_token(&state)

```
int next_token(struct parse_state *state)
{
    //文本的开始的头指针
    char *x = state->ptr;
    char *s;
      
    if (state->nexttoken) {
        int t = state->nexttoken;
        state->nexttoken = 0;
        return t;
    }

    for (;;) {
        switch (*x) {
        case 0:
            state->ptr = x;
            return T_EOF;
        case '\n':
            x++;
            state->ptr = x;
            return T_NEWLINE;
        case ' ':
        case '\t':
        case '\r':
            x++;
            continue;
        case '#':
            while (*x && (*x != '\n')) x++;
            if (*x == '\n') {
                state->ptr = x+1;
                return T_NEWLINE;
            } else {
                state->ptr = x;
                return T_EOF;
            }
        default:
            goto text;
        }
    }

textdone:
    state->ptr = x;
    *s = 0;
    return T_TEXT;
text:
    state->text = s = x;
```

## 3.parse_new_section(&state, kw, nargs, args)

```
static void parse_new_section(struct parse_state *state, int kw,
                       int nargs, char **args)
{
    printf("[ %s %s ]\n", args[0],
           nargs > 1 ? args[1] : "");
    switch(kw) {
   //3.1 解析L_service
    case K_service:
         //3.1.1
        state->context = parse_service(state, nargs, args);
        if (state->context) {
            state->parse_line = parse_line_service;
            return;
        }
        break;
    //3.2接续K_on    
    case K_on:
        state->context = parse_action(state, nargs, args);
        if (state->context) {
            state->parse_line = parse_line_action;
            return;
        }
        break;
      //3.3解析K_import  
    case K_import:
        parse_import(state, nargs, args);
        break;
    }
    state->parse_line = parse_line_no_op;
}
```

#### 3.1.1parse_service(state, nargs, args)

```
static void *parse_service(struct parse_state *state, int nargs, char **args)
{
    if (nargs < 3) {
        parse_error(state, "services must have a name and a program\n");
        return 0;
    }
    if (!valid_name(args[1])) {
        parse_error(state, "invalid service name '%s'\n", args[1]);
        return 0;
    }
    //查询服务是否创建
    service* svc = (service*) service_find_by_name(args[1]);
    if (svc) {
        parse_error(state, "ignored duplicate definition of service '%s'\n", args[1]);
        return 0;
    }

    nargs -= 2;
    //未创建服务开辟内存空间
    svc = (service*) calloc(1, sizeof(*svc) + sizeof(char*) * nargs);
    if (!svc) {
        parse_error(state, "out of memory\n");
        return 0;
    }
    svc->name = strdup(args[1]);
    svc->classname = "default";
    memcpy(svc->args, args + 2, sizeof(char*) * nargs);
    trigger* cur_trigger = (trigger*) calloc(1, sizeof(*cur_trigger));
    svc->args[nargs] = 0;
    svc->nargs = nargs;
    list_init(&svc->onrestart.triggers);
    cur_trigger->name = "onrestart";
    list_add_tail(&svc->onrestart.triggers, &cur_trigger->nlist);
    list_init(&svc->onrestart.commands);
    //添加到service_list末尾
    list_add_tail(&service_list, &svc->slist);
    return svc;
}
```