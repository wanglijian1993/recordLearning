# ArkTS装饰器

## Builder装饰器
Builder装饰的函数也叫"自定义构造函数",是一个轻量级ui复用机制。

自定义组件内自定义构建函数
定义的语法：

`@Builder MyBuilderFunction() { ... }`

全局自定义构建函数
定义的语法

`@Builder function MyGlobalBuilderFunction() { ... }`

*如果不涉及组件状态变化，建议使用全局的自定义构建方法

## BuilderParam装饰器
开发者给自定义组件定制功能的时候使用BuilderParam装饰器，定义有参和无参方法，通过父组件传递具体实例方法
class Tmp{
  label:string=''
}

@Builder function overBuilder($$ :Tmp){
  Text($$.label)
    .width(400)
    .height(50)
    .backgroundColor(Color.Green)

}

@Component
struct Child{
  label:string ='Child'
  @Builder customBuilder(){}
  @BuilderParam customBuilderParams:() => void =this.customBuilder

  @BuilderParam customOverBuilderParam:($$ : Tmp)=> void = overBuilder;

  build() {
  Column(){
    this.customBuilderParams()
    this.customOverBuilderParam({label:'gobal Builder label'})
  }
  }

}

@Entry
@Component
struct Parent{
  label:string ='Parent'

  @Builder componentBuilder(){
    Text(`${this.label}`)
  }

  build() {
  Column(){
    this.componentBuilder()
    Child({customBuilderParams:this.componentBuilder,customOverBuilderParam:overBuilder})
  }
  }
}
## wrapBuilder装饰器

## Style装饰器
## Extend装饰器
## stateStyles装饰器
## AnimatableExtend装饰器
## Required装饰器
