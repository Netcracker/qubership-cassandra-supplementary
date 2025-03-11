/*
Copyright 2022.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controllers

import (
	"context"
	"fmt"

	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"

	"github.com/Netcracker/qubership-cassandra-supplementary/api/v1alpha1"
	impl "github.com/Netcracker/qubership-cassandra-supplementary/pkg"
	"github.com/Netcracker/qubership-nosqldb-operator-core/pkg/core"
	"github.com/Netcracker/qubership-nosqldb-operator-core/pkg/types"
)

// CassandraSupplServiceReconciler reconciles a CassandraService object
type CassandraSupplServiceReconciler struct {
	client.Client
	Scheme     *runtime.Scheme
	Reconciler reconcile.Reconciler
}

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
func (r *CassandraSupplServiceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	_ = log.FromContext(ctx)
	return r.Reconciler.Reconcile(ctx, req)
}

// SetupWithManager sets up the controller with the Manager.
func (r *CassandraSupplServiceReconciler) SetupWithManager(mgr ctrl.Manager) error {
	r.Reconciler = newCassandraServiceReconciler(mgr)
	return ctrl.NewControllerManagedBy(mgr).
		For(&v1alpha1.CassandraSupplService{}).
		Complete(r)
}

func newCassandraServiceReconciler(mgr ctrl.Manager) reconcile.Reconciler {
	return &core.ReconcileCommonService{
		Client:           mgr.GetClient(),
		KubeConfig:       mgr.GetConfig(),
		Scheme:           mgr.GetScheme(),
		Executor:         core.DefaultExecutor(),
		Builder:          &impl.CassandraServiceBuilder{},
		PredeployBuilder: &impl.PreDeployBuilder{},
		Reconciler:       NewCassandraServiceInstanceReconciler(),
	}
}

// blank assignment to verify that ReconcileCassandraService implements reconcile.Reconciler
var _ reconcile.Reconciler = &core.ReconcileCommonService{}

type CassandraServiceInstanceReconciler struct {
	Instance *v1alpha1.CassandraSupplService
}

func NewCassandraServiceInstanceReconciler() core.CommonReconciler {
	return &CassandraServiceInstanceReconciler{}
}

func (s *CassandraServiceInstanceReconciler) GetConfigMapName() string {
	return "cassandra-services-last-applied-configuration-info"
}

func (s *CassandraServiceInstanceReconciler) GetConsulRegistration() *types.ConsulRegistration {
	return &s.Instance.Spec.ConsulRegistration
}

func (s *CassandraServiceInstanceReconciler) GetConsulServiceRegistrations() map[string]*types.AgentServiceRegistration {
	return s.Instance.Spec.ConsulDiscoverySettings
}

func (s *CassandraServiceInstanceReconciler) SetServiceInstance(client client.Client, request reconcile.Request) {
	cassandraServiceList := &v1alpha1.CassandraSupplServiceList{}
	err := core.ListRuntimeObjectsByNamespace(cassandraServiceList, client, request.Namespace)
	if err != nil {
		msCount := len(cassandraServiceList.Items)
		if errors.IsNotFound(err) || msCount == 0 {
			panic(fmt.Sprintf("No service instance found, err: %v", err))
		}
	}

	s.Instance = &cassandraServiceList.Items[0]
}

func (s *CassandraServiceInstanceReconciler) UpdateStatus(condition types.ServiceStatusCondition) {
	s.Instance.Status.Conditions = []types.ServiceStatusCondition{condition}
}

func (s *CassandraServiceInstanceReconciler) GetStatus() *types.ServiceStatusCondition {
	if len(s.Instance.Status.Conditions) > 0 {
		return &s.Instance.Status.Conditions[0]
	}
	return nil
}

func (s *CassandraServiceInstanceReconciler) GetSpec() interface{} {
	return s.Instance.Spec
}

func (s *CassandraServiceInstanceReconciler) GetInstance() client.Object {
	return s.Instance
}

func (s *CassandraServiceInstanceReconciler) GetDeploymentVersion() string {
	return s.Instance.Spec.DeploymentVersion
}

func (s *CassandraServiceInstanceReconciler) GetVaultRegistration() *types.VaultRegistration {
	return &s.Instance.Spec.VaultRegistration
}

func (s *CassandraServiceInstanceReconciler) UpdateDRStatus(status types.DisasterRecoveryStatus) {

}

func (s *CassandraServiceInstanceReconciler) UpdatePassword() core.Executable {
	return nil
}

func (s *CassandraServiceInstanceReconciler) UpdatePassWithFullReconcile() bool {
	return true
}

func (s *CassandraServiceInstanceReconciler) GetAdminSecretName() string {
	return s.Instance.Spec.Cassandra.SecretName
}

func (s *CassandraServiceInstanceReconciler) GetMessage() string {
	if len(s.Instance.Status.Conditions) > 0 {
		return s.Instance.Status.Conditions[0].Message
	}

	return ""
}
