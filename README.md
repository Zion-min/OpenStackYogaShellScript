# OpenstackYogaInstallScript

## Openstack install 과정
- OpenStack은 클라우드 컴퓨팅 플랫폼으로, 사용자에게 인프라를 제공합니다. OpenStack은 다양한 서비스가 API를통해 메시지를 주고 받는 구조로 되어있습니다.
- 우선 가상머신을 만들어 Control Node, Computing Node에 리소스를 할당해주고, 가이드 상의 네트워크 레이아웃에 맞추어 네트워크 설정을 합니다.
- OpenStack의 서비스는 모두 SQL database안에 정보를 저장하고, 메시지 기반으로 통신을 합니다. 이를 위해 관계형 데이터베이스 MariaDB, 메시지 큐인 RabbitMQ를 설치해 줍니다.
- 인증과 보안을 위해 Memcached, Etcd를 설치합니다.
- Identity service인 Keystone을 먼저 설치합니다. 이를 통해 분리된 서비스 간에 인증을 하고 통신이 가능합니다.
- 구축한 OpenStack 클라우드 사용자에게 VM의 이미지를 할당해주는 서비스인 Glance를 설치합니다.
- JSON 기반의 HTTP API인 Placement 를 설치합니다. 이는 Compute 서비스인 nova가 이용하게 됩니다.  그래서 Nova의 요구사항에 맞추어 Placement의 설정도 해주어야 합니다.
- Compute Service인 Nova를 설치합니다. 엔드유저의 API 요청을 받아 주고, VM인스턴스를 생성 및 스케쥴링 등의 역할을 담당합니다.
- Networking service인 Neutron 을 설치하여, NAT를 통해 물리적 네트워크와 연결된 private network를 만듭니다.
- 사양, VM 이미지 이름, 네트워크, 보안 그룹, 키, 인스턴스 이름 등의 정보로 인스턴스를 생성합니다.
- 생성한 인스턴스들의 대시보드를 볼 수 있는 Horizon 서비스도 설치합니다.

## 테스트 환경

 - Ubuntu 18.04 Server (on KVM)

 - 가상머신의 네트워크 타입 : bridge ( 공유기 네트워크에 직접 연결되기 위함 )

## 스크립트 다운로드 및 환경 설정

```
git clone https://github.com/Zion-min/OpenstackYogaShellScript
cd OpenstackYogaShellScript/
chmod +x *.sh
```

### config.sh 파일 설명

다운로드 및 실행권한 부여 이후 config.sh 파일을 자신의 환경에 맞게 수정해야합니다.

 - **QUIETAPT** 

APT 설치 부분에 QUIET 옵션으로, 1로 설정하면 -quiet 옵션이 들어가 apt 중 output이 최소화 됩니다.

 - **INSTALL_HEAT**

HEAT 설치 여부입니다. 1 이면 설치 스크립트에 heat 설치가 들어가게 됩니다.

 - **INIT_OPENSTACK**
 
오픈스택 가이드의 기본 "인스턴스 실행" 부분의 cirros 이미지 추가,네트워크 생성,연동, 인스턴스 실행을 해주는 스크립트
99-init.sh 실행여부

 - **COMPUTENODE**
 
컴퓨트 노드 수로 0이면 All-In-One 형태로 설치. 해당 숫자만큼 아래 HOST_----[n] 내용이 참조됨. 

 - **HOST_ip, name, pass**
 
서버별 내용을 배열 형태로 입력,[0]은 controller, [1] 부터 compute 서버의 내용 입력.

 - **xxxx_PASS**
 
스크립트에 쓰일 패스워드 파일. 오픈스택에서는 해쉬 형태로 권장하나 테스트 전용으로 기본형태의 패스워드만 사용
필요시 변경해서 사용

### config.sh 파일 설정 예시

#### Case 1

한대 서버에, 히트를 제외하고 apt 출력을 보지 않고 설치를 한 뒤 초기화 스크립트까지 실행.

- [x] APT 최소 출력 (quiet 옵션)
- [ ] HEAT 설치
- [x] 초기화 (Launch a instance)
- [x] 별도 Compute 서버 0 ( controller 서버에 All-In-One 으로 설치)
- [ ] 별도 Compute 서버 1+

만약, 위와 같은 옵션으로 스크립트를 실행하려면 아래 컨피그 처럼 설정하시면 됩니다.

```
QUIETAPT=1
INSTALL_HEAT=0
INIT_OPENSTACK=0
COMPUTENODE=0

HOST_ip[0]=10.0.2.11
HOST_prov_ip[0]=192.168.122.21
HOST_name[0]=controller
HOST_pass[0]=qwe123

...
```

#### Case 2

세대 서버(컨트롤러1,컴퓨트2)에, 히트를 포함해서 apt 출력을 보면서 설치를 한 뒤 초기화 스크립트는 미실행.

- [ ] Yum 최소 출력 (quiet 옵션)
- [x] HEAT 설치
- [ ] 초기화 (Launch a instance)
- [ ] 별도 Compute 서버 0 ( controller 서버에 All-In-One 으로 설치)
- [x] 별도 Compute 서버 1+

만약, 위와 같은 옵션으로 스크립트를 실행하려면 아래 컨피그 처럼 설정하시면 됩니다.

```
QUIETAPT=0
INSTALL_HEAT=1
INIT_OPENSTACK=1
COMPUTENODE=2

HOST_ip[0]=10.0.2.11
HOST_prov_ip[0]=192.168.122.21
HOST_name[0]=controller
HOST_pass[0]=qwe123

HOST_ip[1]=10.0.2.31
HOST_prov_ip[1]=192.168.122.25
HOST_name[1]=compute1
HOST_pass[1]=qwe123

HOST_ip[2]=10.0.2.32
HOST_prov_ip[2]=192.168.122.26
HOST_name[2]=compute2
HOST_pass[2]=qwe123

...
```

## 스크립트 실행

위의 내용을 참고하여 수정이 완료되면 아래 00-pre.sh 를 실행하시면 됩니다.

```
./00-pre.sh
```
