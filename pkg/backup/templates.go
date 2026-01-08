// Copyright 2024-2025 NetCracker Technology Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package backup

import (
	v1nc "github.com/Netcracker/qubership-cassandra-supplementary/api/v1alpha1"
	"github.com/Netcracker/qubership-cassandra-supplementary/pkg/utils"
	v12 "k8s.io/api/apps/v1"
	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func BackupDeploymentTemplate(spec *v1nc.CassandraSupplService, namespace string, env []v1.EnvVar) *v12.Deployment {
	var replicas int32 = 1

	var tolerations []v1.Toleration
	if spec.Spec.Policies != nil {
		tolerations = spec.Spec.Policies.Tolerations
	}

	port := utils.GetHTTPPort(spec.Spec.TLS.Enabled)

	allowPrivilegeEscalation := false
	containers := []v1.Container{
		{
			Name:            utils.BackupDaemon,
			Image:           spec.Spec.Backup.DockerImage,
			ImagePullPolicy: spec.Spec.ImagePullPolicy,
			SecurityContext: &v1.SecurityContext{
				Capabilities: &v1.Capabilities{
					Drop: []v1.Capability{"ALL"},
				},
				AllowPrivilegeEscalation: &allowPrivilegeEscalation,
			},
			Ports: []v1.ContainerPort{
				{
					Name:          "http",
					ContainerPort: port,
					Protocol:      "TCP",
				},
			},
			Env:       env,
			Resources: *spec.Spec.Backup.Resources,
		},
	}

	dc := &v12.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      utils.BackupDaemon,
			Namespace: namespace,
			Labels: map[string]string{
				utils.Name:          utils.BackupDaemon,
				utils.AppName:       utils.BackupDaemon,
				utils.AppInstance:   spec.Spec.Instance,
				utils.AppVersion:    spec.Spec.ArtifactDescriptorVersion,
				utils.AppComponent:  "backend",
				utils.AppPartOf:     spec.Spec.PartOf,
				utils.AppManagedBy:  spec.Spec.ManagedBy,
				utils.AppTechnology: "python",
			},
		},
		Spec: v12.DeploymentSpec{
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					utils.Name: utils.BackupDaemon,
				},
			},
			Replicas: &replicas,
			Template: v1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Namespace: namespace,
					Labels: map[string]string{
						utils.Name:          utils.BackupDaemon,
						utils.AppName:       utils.BackupDaemon,
						utils.AppInstance:   spec.Spec.Instance,
						utils.AppVersion:    spec.Spec.ArtifactDescriptorVersion,
						utils.AppComponent:  "backend",
						utils.AppPartOf:     spec.Spec.PartOf,
						utils.AppTechnology: "python",
					},
				},
				Spec: v1.PodSpec{
					ServiceAccountName: spec.Spec.ServiceAccountName,
					SecurityContext:    spec.Spec.PodSecurityContext,
					PriorityClassName:  spec.Spec.Backup.PriorityClassName,
					Containers:         containers,
					Tolerations:        tolerations,
					NodeSelector:       spec.Spec.Backup.NodeLabels,
				},
			},
		},
	}

	return dc
}

func LegacyBackupDeploymentTemplate(pvcName string, namespace string,
	image string,
	nodeSelector map[string]string,
	resources v1.ResourceRequirements,
	env []v1.EnvVar,
	storageDirectory string,
	emptyDir bool,
	port int32) *v12.Deployment {
	var replicas int32 = 1
	storage := utils.BackupStorage

	var volumeSource v1.VolumeSource
	if emptyDir {
		volumeSource = v1.VolumeSource{
			EmptyDir: &v1.EmptyDirVolumeSource{
				Medium: "",
			},
		}
	} else {
		volumeSource = v1.VolumeSource{
			PersistentVolumeClaim: &v1.PersistentVolumeClaimVolumeSource{
				ClaimName: pvcName,
			},
		}
	}

	allowPrivilegeEscalation := false
	dc := &v12.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      utils.BackupDaemon,
			Namespace: namespace,
			Labels: map[string]string{
				utils.Name: utils.BackupDaemon,
			},
		},
		Spec: v12.DeploymentSpec{
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					utils.Name: utils.BackupDaemon,
				},
			},
			Replicas: &replicas,
			Template: v1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Namespace: namespace,
					Labels: map[string]string{
						utils.Name: utils.BackupDaemon,
					},
				},
				Spec: v1.PodSpec{
					Containers: []v1.Container{
						v1.Container{
							Name:  utils.BackupDaemon,
							Image: image,
							SecurityContext: &v1.SecurityContext{
								Capabilities: &v1.Capabilities{
									Drop: []v1.Capability{"ALL"},
								},
								AllowPrivilegeEscalation: &allowPrivilegeEscalation,
							},
							Ports: []v1.ContainerPort{
								v1.ContainerPort{
									Name:          "http",
									ContainerPort: port,
									Protocol:      "TCP",
								},
							},
							Env:       env,
							Resources: resources,
							VolumeMounts: []v1.VolumeMount{
								v1.VolumeMount{
									Name:      storage,
									MountPath: storageDirectory,
								},
							},
						},
					},
					NodeSelector: nodeSelector,
					Volumes: []v1.Volume{
						{
							Name:         storage,
							VolumeSource: volumeSource,
						},
					},
				},
			},
		},
	}

	return dc
}
